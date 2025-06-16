# typed: true

require 'date'

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
      noti_msg = "Remote std got message from #{client_id}\n#{message[..20]}..."
      priority = App.data.option.priority
      if %w[? !].any?{ message.include?(_1) } then
        priority = 4
      elsif err then
        priority = 6
      end
      App.data.option.notify&.notify('remotestd notify', noti_msg, priority)
    end
  end

  def client_control()
    option = App.data.option
    display_name = option.client
    if display_name then
      type, display_name = display_name[0], display_name[1..]

      if !display_name then
        $stderr.puts("Invalid display name #{display_name}")
        exit 1
      end

      status, result = if type == ?+ then
        cid = nil
        cid = if display_name.include?(?:) then
          m = display_name.match(/([^:]+):([^:]+)/)
          if m then
            display_name = T.must(m[1])
            m[2]
          else
            raise RuntimeError.new("Invalied name #{display_name}")
          end
        end
        App.data.mongodb.client_add(display_name, id: cid)
      elsif type == ?~ then
        client_id = display_name
        App.data.mongodb.client_del(client_id)
      else
        App.data.mongodb.client_list_txt()
      end

      unless status then
        $stderr.puts(result)
        exit 2
      end

      puts(result)
      exit 0
    end
  end


end # end of class member defs
end