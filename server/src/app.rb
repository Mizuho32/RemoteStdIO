# typed: true

require 'date'
require 'json'

require 'nanoid'

require_relative('types')
require_relative('mongoDB')


class App < Sinatra::Base
class << self
  extend T::Sig

  sig { returns(Types::AppData) }
  attr_reader :data

  sig { returns(T::Boolean) }
  attr_accessor :restart

  sig { params(opt: Types::OPTION).void }
  def init(opt)
    db_name = if development?
      'test'
    else
      'remotestd'
    end
    # puts "Open #{db_name} db"

    mongo = MongoDB.new(opt.mongo_host, opt.mongo_port, db_name, opt.user, opt.password)
    @data = Types::AppData.new(mongodb: mongo, option: opt, ws_fronts: [], ws_backs: {})
    @restart = false
    # @mutex = Thread::Mutex.new()
  end

  sig { params(args: T.untyped).void }
  def run!(**args)
    super(**args)
  end

  sig { params(message: String, client_id: String, err: T::Boolean).void }
  def handle_stdout(message, client_id, err=false)
    db_elem = Types::Message.new(message: message,datetime: Time.now, client_id: client_id, err: err)
    result = App.data.mongodb.new_message(db_elem)
    data = {**db_elem.serialize, '_id' => result.inserted_ids.first}
    App.data.ws_fronts.each{ _1.send({type: 'msg', data: data}.to_json) }

    # notify
    if !App.data.option.notify.nil? then
      noti_msg = "Remote std message from #{client_id}\n#{message[..App.data.option.notify_msg_size]}...\nhttp://#{App.data.option.hostname}"
      priority = App.data.option.priority

      if %w[? !].any?{ message.include?(_1) } then
        priority = 4
      elsif err then
        priority = 6
      end

      App.data.option.notify&.notify('remotestd notify', noti_msg, priority) if priority > 0
    end
  end

  sig{ params(query: String).returns([String, String, T.nilable(String), Hash])}
  def parse_client_query(query)
  catch :invalid_query do
    throw :invalid_query if query.size < 2
    cmd, operands = query[0], query[1..]

    # parse params
    params = {}
    names = if operands&.include? ?{ then
      m = operands.match(/(?<names>[^\{}]+)(?<params>\{[^\}]+\})/)
      throw :invalid_query if m.nil? 

      params = JSON.parse(m[:params].to_s, symbolize_names: true) # parse {...}
      m[:names]&.strip()
    else
      operands
    end
    throw(:invalid_query) if names.nil?

    # parse display name and cid
    display_name = names
    cid = if names.include? ?:  then
      m = names.match(/(?<display_name>[^:]+):(?<cid>[^:]+)/)
      throw :invalid_query if m.nil? 
      display_name = m[:display_name]
      m[:cid]
    else
      nil
    end
    throw(:invalid_query) if display_name.nil? or cmd.nil?

    return cmd, display_name, cid, params
  end
    raise RuntimeError.new("Invalid query #{query}")
  end

  def client_control()
  msg, exit_status = catch :invalid_query do
    option = App.data.option
    query_string = option.client
    if query_string then
      cmd, display_name, cid, params = parse_client_query(query_string)

      throw :invalid_query, ["Invalid display name #{query_string}", 1] if display_name.empty?

      status, result = if cmd == ?+ then
        App.data.mongodb.client_add(query_string, id: cid)
      elsif cmd == ?= then
        puts "Edit #{display_name}:#{cid} #{params}"
        App.data.mongodb.client_update(display_name, id: cid, params: params)
      elsif cmd == ?- then
        throw :invalid_query, ["client_id is '#{cid}'. Invalid query #{query_string}.", 1] if cid.nil?
        App.data.mongodb.client_del(cid)
      else
        App.data.mongodb.client_list_txt()
      end

      throw :invalid_query, [result, 3] unless status

      puts(result)
      exit 0
    else
      return
    end
  end # catch end
  rescue RuntimeError => ex
    msg = ex.message
    exit_status = 2
  ensure
    $stderr.puts(msg) unless msg.nil?
    exit exit_status unless exit_status.nil?
  end # method end


end # end of class member defs
end