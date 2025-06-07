# typed: true

require 'sinatra'
require 'sorbet-runtime'
require 'faye/websocket'

require_relative('mongoDB')

if !defined?(DEFINE_ONCE) and Sinatra::Base.development? then
module Types
  extend T::Sig

  class OPTION < T::Struct
    prop :bind, String, default: '0.0.0.0'
    prop :port, Integer, default: 8000
    prop :debug, T::Boolean, default: false
    prop :backend, String, default: 'puma'
    prop :mongo_host, String, default: 'localhost'
    prop :mongo_port, Integer, default: 27017

    prop :client, T.nilable(String), default: nil
  end

  class AppData < T::Struct
    const :mongodb, MongoDB
    const :option, Types::OPTION
    const :ws_fronts, T::Array[Faye::WebSocket]
    const :ws_backs,  T::Hash[Symbol, Faye::WebSocket]
  end

  class Message < T::Struct
    const :message, String
    const :datetime, Time
    # const :id, String
    const :client_id, String
    const :err, T::Boolean
  end

  class Client < T::Struct
    const :display_name, String
    const :client_id, String
  end

  class ExtractState
    extend T::Sig
    attr_reader :thread
    attr_accessor :current_songname

    sig { params(filename: String).void }
    def initialize(filename)
      @filename = filename
      @current_songname = ''
      @thread = T.let(nil, T.nilable(Thread))
    end

    sig { params(thread: Thread).void }
    def set_thread(thread)
      @thread = thread
    end
  end

  class WSSession
    extend T::Sig

    sig { returns(String) }
    attr_reader :id
    attr_reader :ws

    sig { params(id: String, ws: T.untyped).void }
    def initialize(id, ws)
      @id = id
      @ws = ws
    end
  end
end
end