# typed: true

require 'net/http'
require 'uri'
require 'net/http/post/multipart'

class Notify
  extend T::Sig

  sig {params(domain: String, token: String, https: T::Boolean).void}
  def initialize(domain, token, https = true)
    protocol = if https then 'https' else 'http' end
    @uri = URI.parse("#{protocol}://#{domain}/message?token=#{token}")
  end

  sig {params(title: String, message: String, priority: Integer).void}
  def notify(title, message, priority=0)
    request = Net::HTTP::Post::Multipart.new(
      @uri,
      "title" => title,
      "message" => message,
      "priority" => "#{priority}"
    )

    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = (@uri.scheme == "https")

    reseonse = http.request(request)

    # puts response.code
    # puts response.body
  end
end