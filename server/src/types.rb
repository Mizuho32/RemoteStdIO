# typed: true

require 'sinatra'
require 'sorbet-runtime'
require 'faye/websocket'

require_relative('mongoDB')
require_relative('notify')

if !defined?(DEFINE_ONCE) then
module Types
  extend T::Sig

  MONGO_MAX_COUNT = 50
  DIRECTION_PAST  = true

  class OPTION < T::Struct
    prop :bind, String, default: '0.0.0.0'
    prop :port, Integer, default: 8000
    prop :debug, T::Boolean, default: false
    prop :backend, String, default: 'puma'
    prop :mongo_host, String, default: 'localhost'
    prop :mongo_port, Integer, default: 27017
    prop :user, T.nilable(String), default: nil
    prop :password, T.nilable(String), default: nil
    prop :priority, Integer, default: if Sinatra::Base.development? then 0 else -1 end
    prop :hostname, String, default: ''
    prop :notify_msg_size, Integer, default: 30

    prop :client, T.nilable(String), default: nil
    prop :notify, T.nilable(Notify), default: nil
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
    const :message_format, T.nilable(String)
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