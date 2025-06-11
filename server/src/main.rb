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

if !defined?(DEFINE_ONCE) and Sinatra::Base.development? then
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
DEFINE_ONCE=true

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
        .select{|file| file.basename.to_s != "server.rb"}
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
    puts(data[:client_id], data[:message][0..30]) if App.data.option.debug

    App.handle_stdout(data[:message], data[:client_id])
  end

  get '/stdout' do
    _id = params["_id"]
    client_id = params['client_id']
    if !client_id.nil? then
      json(App.data.mongodb.get_messages(client_id, _id))
    else
      status 404
    end
  end

  post '/stdin' do
    request.body.rewind  # 必須：bodyの読み取り前にポインタを先頭に戻す
    data = JSON.parse(request.body.read, symbolize_names: true)
    client_id = data[:client_id]
    if !client_id.nil? then
      App.data.ws_backs[client_id.to_sym].send(data[:message].to_s)
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

      ws.on :open do |event|
        puts "WS open #{ws}"
        settings.sockets << ws
        App.data.ws_fronts << ws

        # Open stdins already connected
        App.data.ws_backs.each{|client_id, _|
          puts "Already connected client #{client_id}. open."
          ws.send({type: 'stdin', data: {status: 'open', client_id: client_id.to_s}}.to_json)
        }
      end

      ws.on :message do |event|
        puts "WS msg #{event.data}"

        # settings.sockets.each do |socket|
        #   socket.send(event.data)
        # end
      end

      ws.on :close do |event|
        puts "WS close #{ws}"
        settings.sockets.delete(ws)
        App.data.ws_fronts.delete(ws)
      end

      ws.rack_response
    end
  end

  get %r'/(api/)?websocket/back' do
    if Faye::WebSocket.websocket?(request.env) then
      ws = Faye::WebSocket.new(request.env)
      will_close = Thread.new {
        sleep 5
        ws.close
        puts "closed #{ws}"
      }

      ws.on :open do |event|
        puts "BWS open #{ws}"
        settings.sockets << ws
      end

      ws.on :message do |event|
        puts "BWS msg #{event.data}"
        client_id = T.let(event.data, String).to_sym
        puts "WARNING: #{client_id} already registered. Overwrite" if App.data.ws_backs[client_id]

        App.data.ws_backs[client_id] = ws
        App.data.ws_fronts.each{
           _1.send({type: 'stdin', data: {status: 'open', client_id: client_id.to_s}}.to_json)
        }

        will_close.kill
      end

      ws.on :close do |event|
        puts "BWS close #{ws}"

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
    puts "proxy #{api_name} to :#{current_port}"

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)

    response = http.request(request)
    status response.code
    body response.body
  end
end
