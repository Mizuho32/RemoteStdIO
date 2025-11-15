#  typed: true
  
require 'net/http'
require 'uri'
require 'json'
require 'delegate'
require 'logger'

require 'sorbet-runtime'
require 'websocket-client-simple'

extend T::Sig

LOGGER = Logger.new(STDOUT)
set_level = ENV['LOG_LEVEL'].to_s.to_sym
LOGGER.level = ( (Logger.constants.include?(set_level) && Logger.const_get(set_level)) || Logger::INFO )


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
    @got_msg = T.let(false, T.any(T::Boolean, Integer))
    @connection = WhineThread.new {
      # ws simple's self in ws.on block is not WSIN!
      msg = @msg
      got_msg = @got_msg
      client_id = @client_id
      q = Queue.new

      loop do
        ws = WebSocket::Client::Simple.connect("ws://#{host}/websocket/back")

        ws&.on :open do |event|
          LOGGER.debug("WSIN opend. send ack #{client_id.inspect}")
          ws.send(client_id)
        end

        ws&.on :message do |event|
          LOGGER.debug("WSIN msg #{event.data.inspect}")
          data = JSON.parse(event.data, symbolize_names: true)
          status = T.let(data[:status].to_i, Integer)
          msg, got_msg = if status == 200 then
            tmp = T.let(data[:data].to_s, String)
            # [msg, got_msg]
            [tmp, true]
          else
            ['', status]
          end
          q << got_msg
          ws.close()
        end

        ws&.on :close do |event|
          LOGGER.debug("WSIN :close #{event.code} #{event.reason}")
          if got_msg then
            ws = nil
            EM.stop
            LOGGER.error("WSIN refused. already stdin opened?") if got_msg == 403
          else
            LOGGER.warn("WSIN closed before msg. Retry after 10s")
            sleep 10
          end
        end

        q.pop # wait
        break if got_msg
      end # loop

      @got_msg = got_msg
      @msg     = msg
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

    sig {params(a: T.untyped, err: T::Boolean, noremote: T::Boolean).returns(NilClass)}
    def puts(*a, err:false, noremote: false)
      self.write(a.map(&:to_s).join("\n") + "\n", err: err) if !noremote
      return nil
    end

    sig {params(a: T.untyped, err: T::Boolean, noremote: T::Boolean).returns(NilClass)}
    def print(*a, err:false, noremote: false)
      self.write(a.map(&:to_s).join, err: err) if !noremote
      return nil
    end

    sig {params(a: T.untyped, err: T::Boolean, noremote: T::Boolean).returns(NilClass)}
    def p(*a, err:false, noremote: false)
      self.write(a.map(&:inspect).join, err: err) if !noremote
      return nil
    end

    sig {params(retval: T.nilable(String), threads: T::Hash[Symbol, T.nilable(WhineThread)], counter_key: Symbol, trial: Integer).returns(T.nilable(String))}
    def handle_concurrency(retval, threads, counter_key, trial: 3)
      @mutex.synchronize do
        counter = catch :counter do
          trial.times {
            canbe_couter = threads[counter_key]
            throw :counter, canbe_couter unless canbe_couter.nil?
            sleep 0.5
          }
          LOGGER.error("Failed to get #{counter_key} thead for gets")
          nil
        end
        return nil if counter.nil?

        if counter&.status then
          LOGGER.debug("Will kill #{counter_key} stdin")
          counter.kill
        end
      end
      return retval
    end

    sig {params(a: String, noremote: T::Boolean, kw: String).returns(String)}
    def gets(*a, noremote: false, **kw)
      return STDIN.gets(*T.unsafe(a), **kw) if @client_id.nil? || noremote

      threads = T.let({}, T::Hash[Symbol, WhineThread])
      wsin = WSIN.new(@host, @client_id)
      @retval = T.let(nil, T.nilable(String))

      threads[:STDIN] = WhineThread.new {
        retval = T.let(STDIN.gets(*T.unsafe(a)), T.nilable(String))
        LOGGER.debug("STDIN got #{retval.inspect}")
        if !retval.nil? then # if nil, close STDIN thread and wait wsin
          wsin.got_msg = true # break wsin gets loop to avoid loop even after ws.close
          @retval = handle_concurrency(retval, threads, :wsin) 
        end
      }
      threads[:wsin] = WhineThread.new {
        retval = wsin.gets(*T.unsafe(a))
        LOGGER.debug("wsin got #{retval.inspect}")
        @retval = handle_concurrency(retval, threads, :STDIN) 
      }

      threads.each{|_, t| t.join }
      return @retval.to_s
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
  if ARGV.delete_at(0)&.downcase&.include?(?a) then
    print(
"""## Hello world
**At #{Time.now.iso8601}**
~~Test text~~
[line-through]#Test text#

* [.red]#赤くする#
* [.green]#緑にする#

[.navy]#Input# >>""")
  else
    print(
"""## Hello world
**At #{Time.now.iso8601}**
~~Test text~~
````
## This is
```bash
echo raw code ${HOME}
```
````

```bash
$ ls ${HOME}
```

Input >>""")
  end
  val = gets()
  $stderr.puts("Got #{val}")
  p(val)
end
