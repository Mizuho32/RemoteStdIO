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

    mongo = MongoDB.new(opt.mongo_host, opt.mongo_port, db_name)
    @data = Types::AppData.new(mongodb: mongo, option: opt, ws_fronts: [], ws_backs: {})
    @restart = false
    # @mutex = Thread::Mutex.new()
  end

  sig { params(args: T.untyped).void }
  def run!(**args)
    super(**args)
  end

  sig { params(message: String, client_id: String).void }
  def handle_stdout(message, client_id)
    db_elem = Types::Message.new(message: message,datetime: Time.now, client_id: client_id, err: false)
    result = App.data.mongodb.new_message(db_elem)
    data = {**db_elem.serialize, '_id' => result.inserted_ids.first}
    App.data.ws_fronts.each{ _1.send({type: 'msg', data: data}.to_json) }
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
        App.data.mongodb.client_add(display_name)
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