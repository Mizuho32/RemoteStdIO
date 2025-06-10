# typed: true

require 'pathname'
require 'optparse'

require_relative('src/types')

option = Types::OPTION.new()

parser = OptionParser.new

# parser.on("--id-map id_map.yaml", "id map config") {|v| option.id_map = Pathname(v) }
parser.on('-d', "--debug", "Debug mode") { option.debug = true }
parser.on('-b', "--backend [thin]", "puma thin webrick") {|v| option.backend = v }
parser.on('-p', "--port [8000]", "port") {|v| option.port = v.to_i }
parser.on('-b', "--bind [0.0.0.0]", "bind") {|v| option.bind = v }
parser.on("--mongo-host [localhost]", "mongo host") {|v| option.mongo_host = v}
parser.on("--mongo-port [27017]", "mongo port") {|v| option.mongo_port = v.to_i }
parser.on("--client [nil]", "client optration. ex. '+user'") {|v| option.client = v }
parser.on('-n', "--notify-config [notify_conf.yaml]", "config of notification (e.g. gotify)") {|v|
  require 'yaml'
  yaml = YAML.load_file(v)
  T.must(yaml[:domain])
  T.must(yaml[:token])
  option.notify = Notify.new(yaml[:domain], yaml[:token])
}

parser.parse!(ARGV)

# For sinatra help
# if not ARGV.map{|el| el =~ /h(elp)?/}.any? then
  # begin
    # parser.parse!(ARGV)
  # rescue StandardError
    # STDERR.puts parser
    # exit 1
  # end
# else
  # puts parser.help
# end

# require_relative 'src/profile' if option[:performance]

# require_relative 'src/utils'
# require_relative 'src/backend'
require_relative 'src/main'

# new_port, audio_backend = Utils.init(option)
# puts "Specified #{option[:port]} but will use #{new_port}"

App.init(option)
App.client_control()

trap(:INT) {
  App.stop!
}


catch(:end) do
  loop do
    App.run!(
      public_folder: (Pathname(T.must(__dir__)) / "public"),
      views:         (Pathname(T.must(__dir__)) / "views"),
      server: option.backend,
      sockets: [],
      port: option.port,
      bind: option.bind,
    )
    throw :end unless App.restart
  end
end

puts "End"