# typed: true

require 'open-uri'
require 'json'
# require 'csv'
require 'date'
require 'mime/types'
require 'net/http'

#require 'sinatra/reloader' if development?
# require 'oga'
require 'sinatra'
require "sinatra/json"
# require 'sinatra-websocket'
require 'faye/websocket'
require 'rack'
require 'nanoid'
require 'sorbet-runtime'

require_relative 'types'
require_relative 'app'
# require_relative 'utils'
# require_relative 'song_utils'

#use Rack::Chunked
#use Rack::ContentLength

if !defined?(DEFINE_ONCE) then
class Sinatra::Base
  class << self
    extend T::Sig
    alias_method :original_get, :get
    alias_method :original_post, :post

    def err_handle(&block)
      Proc.new do
        begin
          instance_eval(&block)
        rescue StandardError => ex
          backtrace = ex.backtrace&.select{|line| !line.include?("bundle")}
          puts ex.message, backtrace&.join("\n")
          #raise ex
          halt 500
        end
      end
    end

    # get with Exception handle
    def get(path, opts = {}, &block)
      new_block = err_handle(&block)
      original_get(path, opts, &new_block)
    end

    sig {params(path: T.untyped, opts: T.untyped, block: T.proc.returns(T.untyped)).returns(T.untyped)}
    def post(path, opts = {}, &block)
      new_block = err_handle(&block)
      original_post(path, opts, &new_block)
    end

  end # meta class definition end
end
end

class App < Sinatra::Base
  extend T::Sig

  # https://hawksnowlog.blogspot.com/2024/11/sinatra-410-must-be-set-permitted-hosts.html?m=1
  set :host_authorization, { permitted_hosts: [] }
  configure :development do
    #register Sinatra::Reloader

    require "sinatra/reloader"
    register Sinatra::Reloader

    get '/restart' do
      App.restart = true
      App.quit!
    end

    get '/reload' do
      Pathname("src/").glob("*.rb")
        .select{|file| %w[remotestdio].all?{|ignore| !file.basename.to_s.include?(ignore)} }
        .each{|file|
          puts "reload #{file}"
          begin
            load file.to_s
          rescue StandardError, LoadError => ex
            puts "  load #{file} error:\n#{ex.message}"
          end
        }.all?
    end
  end

  # if defined?(OPTION) && OPTION[:performance] then
  #   use Rack::RubyProf, path: 'data', only_paths: [%r{/audio}]
  # end

  post '/stdout' do
    request.body.rewind  # 必須：bodyの読み取り前にポインタを先頭に戻す
    data = JSON.parse(request.body.read, symbolize_names: true)
    App.logger.debug("/stdout cid=#{data[:client_id]} msg=#{data[:message][0..30]}")

    App.handle_stdout(data[:message], data[:client_id], data[:err])
  end

  get '/stdout' do
    _id = params["_id"]
    client_id = params['client_id']
    max_count = (params['max_count'] || Types::MONGO_MAX_COUNT).to_i
    direction_past = if tmp = params['direction_past'] then !tmp.to_i.zero? else Types::DIRECTION_PAST end

    if !client_id.nil? then
      json(App.data.mongodb.get_messages(client_id, _id, max_count, direction_past))
    else
      status 404
    end
  end

  post '/stdin' do
    request.body.rewind  # 必須：bodyの読み取り前にポインタを先頭に戻す
    data = JSON.parse(request.body.read, symbolize_names: true)
    client_id = data[:client_id]
    ws = App.data.ws_backs[client_id.to_sym]
    if ws then
      ws.send({status: 200, data: data[:message].to_s}.to_json)
      status 200
    else
      status 404
    end
  end

  get '/clients' do
    json(App.data.mongodb.client_list)
  end


  get '/' do
    send_file File.join(settings.public_folder, 'index.html')
  end

  get %r'/(api/)?websocket/front' do
    if Faye::WebSocket.websocket?(request.env) then
      ws = Faye::WebSocket.new(request.env)
      # クライアントの IP アドレスを取得
      ip = request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_ADDR']

      ws.on :open do |event|
        App.logger.info("WSF open for #{ip}")
        settings.sockets << ws
        App.data.ws_fronts << ws

        # Notify already opened stdins to newly clients
        App.data.ws_backs.each{|client_id, _|
          App.logger.info "For stdin of #{client_id} already opened, client #{ip} connected."
          ws.send({type: 'stdin', data: {status: 'open', client_id: client_id.to_s}}.to_json)
        }
      end

      ws.on :message do |event|
        App.logger.debug("WSF msg '#{event.data[0]}...#{event.data[-1]}' from #{ip}")

        # settings.sockets.each do |socket|
        #   socket.send(event.data)
        # end
      end

      ws.on :close do |event|
        App.logger.info("WSF closed for #{ip}")
        settings.sockets.delete(ws)
        App.data.ws_fronts.delete(ws)
      end

      ws.rack_response
    end
  end

  get %r'/(api/)?websocket/back' do
    if Faye::WebSocket.websocket?(request.env) then
      ws = Faye::WebSocket.new(request.env)
      ip = T.let((request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_ADDR']).to_sym, Symbol)
      will_close_without_clientid_get = Thread.new {
        sleep 5
        App.logger.warn("WSB closed for #{ip} no client_id notify")
        ws.close
      }

      ws.on :open do |event|
        App.logger.info("WSB opened for #{ip}")
        settings.sockets << ws
      end

      ws.on :message do |event|
        client_id = T.let(event.data, String).to_sym
        if App.data.ws_backs[client_id] then
          App.logger.warn("#{client_id}@#{ip} already registered. close.")
          ws.send({status: 403, data: "#{client_id}@#{ip} already registered. close."}.to_json)
          ws.close
          next
        end

        App.logger.info("WSB client add #{client_id.inspect}")
        App.data.ws_backs[client_id] = ws
        App.data.ws_fronts.each{
           _1.send({type: 'stdin', data: {status: 'open', client_id: client_id.to_s}}.to_json)
        }

        will_close_without_clientid_get.kill
      end

      ws.on :close do |event|
        App.logger.info("WSB close #{ip}")

        App.data.ws_backs.delete_if{|cid, ws_cand|
          if ws_cand == ws then
            App.data.ws_fronts.each{
              _1.send({type: 'stdin', data: {status: 'close', client_id: cid.to_s}}.to_json)
            }
            next true
          end
        }
        settings.sockets.delete(ws)
      end

      ws.rack_response
    end
  end

  get '/api/:api_name' do
    api_name = params[:api_name]
    current_port = settings.port
    query_string = request.query_string
    uri = URI.parse("http://localhost:#{current_port}/#{api_name}?#{query_string}")
    App.logger.debug("GProxy #{api_name} to :#{current_port}/#{api_name}")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)

    response = http.request(request)
    status response.code
    body response.body
  end

  post '/api/:api_name' do
    api_name = params[:api_name]
    current_port = settings.port
    query_string = request.query_string
    uri = URI.parse("http://localhost:#{current_port}/#{api_name}?#{query_string}")
    App.logger.debug("PProxy #{api_name} to :#{current_port}/#{api_name}")

    http = Net::HTTP.new(uri.host, uri.port)

    # POSTリクエストを構築
    req = Net::HTTP::Post.new(uri.request_uri)

    # ヘッダー転送（必要に応じて制限を加える）
    request.env.each do |key, value|
      if key.start_with?('HTTP_')
        header_name = key.sub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
        req[header_name] = value unless header_name == 'Host'
      end
    end

    # Content-Type など明示的にセット
    req['Content-Type'] = request.content_type if request.content_type

    # リクエストボディを渡す
    req.body = request.body.read

    # レスポンスを転送
    response = http.request(req)
    status response.code
    body response.body
  end
end
