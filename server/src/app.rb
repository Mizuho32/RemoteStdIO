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


  sig { params(id: T.nilable(String)).returns(String) }
  def get_artist(id)
    return @id_map[id.to_sym]&.[](:system_name).to_s if id
    ""
  end

  sig { params(id: T.nilable(String)).returns(String) }
  def get_tag_artist(id)
    return @id_map[id.to_sym]&.[](:tag_name).to_s if id
    ""
  end

  sig { params(process_id: Symbol, block: Proc).returns(T.nilable(Thread)) }
  def extract(process_id, &block)
    raise StandardError.new('nil @extract_threads') if @extract_threads.nil?
    t = Thread.new(block)
    @extract_threads[process_id] = t

    t.join()
    @extract_threads.delete(process_id)
  end

  sig { params(artist: String).returns([T::Boolean, Pathname]) }
  def artist_exists?(artist)
    det_root = T.let(App.option[:det_root], Pathname)
    artist_path = det_root / artist

    if !artist.empty? && artist_path.directory? then
      return  true, artist_path
    else
      return false, artist_path
    end
  end

  sig { params(artist_nanoid: T.nilable(String), artist_existing_path: T.nilable(Pathname)).returns(T.any(Integer, T::Boolean)) }
  def extracts(artist_nanoid, artist_existing_path: nil)
    artist = App.get_artist(artist_nanoid)
    return 404 if artist.empty?
    tag_artist = App.get_tag_artist(artist_nanoid)

    artist_exists, artist_existing_path = if artist_existing_path.nil? then
      App.artist_exists?(artist)
    else
      [true, artist_existing_path]
    end

    monitor = Proc.new{
        loop {
          sleep 1
          p_size = App.extract_controller&.get_state(artist)&.size
          puts "processes for #{artist} is #{p_size}"
          break if p_size&.zero?
        }
      }
    if !defined?(@tmp_state) then
      @tmp_state&.kill
    end
    @tmp_state = Thread.new(&monitor)

    if artist_exists then
      cache_dir = App.option[:cache_root]

      Thread.new {
      begin
      App.list[artist.to_sym].each_with_index{|(filestemname, song_info), idx|
        # break if idx > 4
        filename = "#{filestemname}#{song_info[:extname]}"
        file_path = artist_existing_path / filename
        tags_csv  = artist_existing_path / "identified" / filestemname.to_s / "tags.csv"

        # App.extract_controller&.extract(artist, filename) do |session|
          if tags_csv.exist? then
              puts("#{artist}, #{tags_csv}")#, file_path, cache_dir)
              if ex = App.extract_controller
                SongUtils.extract_songs(artist, tag_artist, Utils.load_tags(tags_csv), file_path, cache_dir, ex, App.tmp_dir, suppress_print: true)
              else
                $stderr.puts "extract_controller is nil"
              end
          end
      }
        # rescue StandardError => ex
        #   puts "#{ex.message}\n#{ex.backtrace&.join("\n")}"
        # end

      # disconnect WS
      # App.extract_controller&.mutex&.synchronize do
      #   if ws_sessions = App.extract_controller&.ws_sessions then
      #     puts "All #{artist} processed"
      #     artist_sym = artist.to_sym
      #     ws_sessions[artist_sym]&.each{ |_, ws| ws.close_connection() }
      #     ws_sessions[artist_sym] = {}
      #   end
      # end
      rescue StandardError => ex
      puts "#{ex.message}\n#{ex.backtrace&.join("\n")}"
      end
      }
      return true
    else
      return false
    end
  end
end # end of class member defs
end