#  typed: true
  
require 'net/http'
require 'uri'
require 'json'
require 'delegate'

require 'sorbet-runtime'
require 'faye/websocket'


class WhineThread < Thread
  extend T::Sig
  sig {params(blk: T.proc.void).void}
  def initialize(&blk)
    super() {
      begin
        blk.call
      rescue StandardError => ex
        STDERR.puts(ex.message, ex.backtrace&.join("\n"))
      end
    }
  end
end

class WSIN
  extend T::Sig
  attr_accessor :got_msg

  sig {params(host: String, client_id: String).void}
  def initialize(host, client_id)
    @client_id = client_id
    @host = host
    @msg = ''
    @got_msg = T.let(false, T::Boolean)
    @connection = WhineThread.new {
      loop do
        EM.run {
        ws = T.let(Faye::WebSocket::Client.new("ws://#{host}/websocket/back"), T.nilable(Faye::WebSocket::Client))

        ws&.on :open do |event|
          #p [:open]
          ws.send(@client_id)
        end

        ws&.on :message do |event|
          #p [:message, event.data]
          #if event.data.include?('close') then
            @msg = event.data
            @got_msg = true
            ws.close()
            #EM.stop
          #end
        end

        ws&.on :close do |event|
          #p [:close, event.code, event.reason]
          if @got_msg then
            ws = nil
            EM.stop
          else
            STDOUT.puts("WS closed before msg. Retry after 10s")
            sleep 10
            ws = Faye::WebSocket::Client.new("ws://#{host}/websocket/back")
          end
        end
        }
        break if @got_msg
      end
    }
  end

  sig{ params(a: String).returns(String)}
  def gets(*a)
    @connection.join
    return @msg
  end
end

class RemoteSTDIO
  class << self
    extend T::Sig

    sig {params(host: String, id: String).void}
    def init(host, id)
      @host = host # hostname:port
      @url = url = URI.parse("http://#{host}/stdout")
      # HTTPリクエストの作成
      @http = Net::HTTP.new(url.host, url.port)
      @http.use_ssl = (url.scheme == 'https')

      @client_id = id
      @mutex = Mutex.new

      $stderr = FakeSTDERR.new($stderr)
    end

    sig {params(msg: String, err: T::Boolean).returns(T.untyped)}
    def write(msg, err: false)
      return if @client_id.nil?

      payload = { message: msg, client_id: @client_id, err: err }.to_json
      request = Net::HTTP::Post.new(@url.path, { 'Content-Type' => 'application/json' })
      request.body = payload

      # リクエスト送信
      return response = @http.request(request)

      # レスポンス表示
      # puts "Response Code: #{response.code}"
      # puts "Response Body: #{response.body}"
    end

    sig {params(a: String, err: T::Boolean, noremote: T::Boolean).void}
    def puts(*a, err:false, noremote: false)
      self.write(a.join("\n") + "\n", err: err) if !noremote
    end

    sig {params(a: String, err: T::Boolean, noremote: T::Boolean).void}
    def print(*a, err:false, noremote: false)
      self.write(a.join, err: err) if !noremote
    end

    sig {params(a: String, noremote: T::Boolean, kw: String).returns(String)}
    def gets(*a, noremote: false, **kw)
      return STDIN.gets(*T.unsafe(a), **kw) if @client_id.nil? || noremote

      threads = T.let([], T::Array[WhineThread])
      wsin = WSIN.new(@host, @client_id)
      @retval = T.let(nil, T.nilable(String))
      threads[0] = WhineThread.new{
        retval = T.let(STDIN.gets(*T.unsafe(a)), T.nilable(String))
        if !retval.nil? then # if nil, close STDIN thread and wait wsin
          wsin.got_msg = true
          counter = threads[1]
          @mutex.synchronize do
            @retval = retval
            if counter&.status then
              counter.kill
            end
          end
        end
      }
      threads[1] = WhineThread.new{
        retval = wsin.gets(*T.unsafe(a))
        counter = threads[0]
        @mutex.synchronize do
          @retval = retval
          if counter&.status then
            counter.kill
          end
        end
      }
      threads.each{ _1.join }
      return @retval || ''
    end

  end
end

class FakeSTDERR < SimpleDelegator
  def puts(*a)
    STDERR.puts(*T.unsafe(a))
    RemoteSTDIO.puts(*T.unsafe(a), err: true)
  end

  def print(*a)
    STDERR.print(*T.unsafe(a))
    RemoteSTDIO.print(*T.unsafe(a), err: true)
  end
end

module Kernel
  %i[puts print gets].each{|method_name|
    orig_name = :"#{method_name}_orig"
    alias_method(orig_name, :"#{method_name}")
    define_method(method_name){|*a, **kw|

      #$stdout.puts("Orig: #{method_name}")
      tmp = [orig_name, *a]
      send(*T.unsafe(tmp)) if method_name != :gets
      tmp = [method_name, *a]
      RemoteSTDIO.send(*T.unsafe(tmp), **kw)
    }
  }
end

module RemoteSTDIOUtils
  include Kernel
  extend self
  attr_accessor :no_remotestdio
  @no_remotestdio = false

  def init_by_envvar()
    host = ENV['HOST'].to_s
    client_id = ENV['CID'].to_s
    if !host.empty? && !client_id.empty? then
      RemoteSTDIO.init(host, client_id)
    else
      puts "WARN puts without remotestdio"
    end
  end

  def safe_gets()
    if RemoteSTDIOUtils.no_remotestdio then
      return STDIN.gets
    else
      return gets
    end
  end
end


# class CIO
#   def write(msg)
#     STDOUT.puts("orig: #{msg.inspect}")
#     STDOUT.write(msg)
#   end
# 
#   def read(msg)
#     STDOUT.print(msg)
#     STDIN.read(msg)
#   end
#   def readline(msg)
#     STDOUT.print(msg)
#     STDIN.readline(msg)
#   end
#   def gets(*a)
#     STDOUT.print('hi',*a)
#     STDIN.gets(*a)
#   end
# end
# 
# $stdin = CIO.new

if __FILE__ == $0
  RemoteSTDIO.init(T.must(ENV['HOST']), T.must(ENV['CID']))
  print("Hello world\n  At #{Time.now.iso8601}\nInput >>")
  val = gets()
  $stderr.puts("Got #{val}")
  p(val)
end
