# typed: true

require 'mongo'
require 'nanoid'

require_relative('types')

class MongoDB
  extend T::Sig

  if !defined?(DEFINE_ONCE) then
  class DBFormat < T::Struct
    const :InBox, Mongo::Collection
    const :Archive, Mongo::Collection
    const :Clients, Mongo::Collection
  end
  end

  # sig {returns{db}}
  # attr_reader :db

  sig {params(host:String, port: Integer, dbname: String, user: T.nilable(String), password: T.nilable(String)).void}
  def initialize(host, port, dbname, user, password)
    @client = Mongo::Client.new([ "#{host}:#{port}" ], user: user, password:password, database: dbname, auth_source: 'admin' )
    
    @db = T.let(DBFormat.new(
      InBox: @client[:InBox], 
      Archive: @client[:Archive],
      Clients: @client[:Clients]), DBFormat)
  end

  sig { params(elem: Types::Message).returns(Mongo::Operation::Insert::Result) }
  def new_message(elem)
    @db.InBox.insert_one(elem.serialize)
  end

  sig { params(client_id: String, _id: T.nilable(String), max_count: Integer).returns(T::Array[Types::Message])}
  def get_messages(client_id, _id, max_count = 10)
    found = if _id.nil? then # latest
      T.let(@db.InBox.find(client_id: client_id), Mongo::Collection::View).sort(datetime: -1).limit(max_count)
    else
      raise NotImplementedError.new()
    end
    return found.map{ _1 }.reverse
  end

  sig {params(display_name: String, id: T.nilable(String)).returns([T::Boolean, String])}
  def client_add(display_name, id: nil)
    found = T.let(@db.Clients.find({ display_name: display_name }), Mongo::Collection::View)
    unless found.count_documents.zero? then
      return false, "'#{display_name}' already exists"
    end

    client_id = if id.nil? then Nanoid.generate(size: 5) else id end
    client = Types::Client.new(display_name: display_name, client_id: client_id)
    @db.Clients.insert_one(client.serialize)
    return true,"'#{display_name}' added"
  end

  sig {params(client_id: String).returns([T::Boolean, String])}
  def client_del(client_id)
    clients2del = @db.Clients.find({ client_id: client_id })

    if clients2del.count_documents.zero? then
      return false, "'#{client_id}' not found"
    end

    client2del = clients2del.first
    result = @db.Clients.delete_one(client2del)
    # client2del = Types::Client.from_hash(client2del)
    return true,"'#{client_id}' deleted #{result}"
  end

  sig {returns(T::Array[Types::Client])}
  def client_list()
    return @db.Clients.find.map{ |elm|
      # T.let(Types::Client.from_hash(elm), Types::Client)
      elm
    }
  end

  sig {returns([T::Boolean, String])}
  def client_list_txt()
    list = @db.Clients.find.map{ |elm|
      client = T.let(Types::Client.from_hash(elm), Types::Client)
      "#{client.display_name}\t#{client.client_id}"
    }.join("\n")

    return true, "Clients:\n#{list}"
  end

end