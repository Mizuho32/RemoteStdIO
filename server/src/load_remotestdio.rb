require_relative 'remotestdio'

begin
  RemoteSTDIOUtils.init_by_envvar()
  NO_REMOTESTDIO = false
rescue LoadError => ex
  puts ex.message
  puts "WARN puts without remotestdio"
  NO_REMOTESTDIO = true
end
