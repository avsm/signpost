#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup' # To ensure the version installed by bundler is used
require 'thin'
require 'scanf'
require 'timeout'
require 'http_server/psp_backend'

gem "json"

begin
  require "json/ext"
rescue LoadError
  $stderr.puts "C version of json (fjson) could not be loaded, using pure ruby one"
  require "json/pure"
end


# information about the client these requests are on
# behalf of
@@user_info = "device.client.com"

# -----------------
# Don't buffer output (for debug purposes)
$stderr.sync = true

@@solver_ip = '127.0.0.1'
@@port = 5000

class NameResolver
  def call(env)
    request = Rack::Request.new(env)
    puts env.inspect
    name = env['REQUEST_PATH'].scan(/[a-zA-Z\.]+/)
    # We are trying to resolve an IP
    request = {
      :what => "ip_for_domain@#{name[1]}",
      :user_info => @@user_info
    }
    s = TCPSocket.open(@@solver_ip, @@port)
    s.puts "#{request.to_json}"
    reply = s.gets
    s.close

    body = [(reply)]
    [
      200,
      { 'Content-Type' => 'application/json' },
      body
    ]
  end
end

# Thin::Server.start('0.0.0.0', 8080) do
#   use Rack::CommonLogger
#  map '/address/' do
#     run NameResolver.new()
#   end
#   map '/files' do
#     run Rack::File.new('.')
#   end
# end

Thin::Server.start('0.0.0.0', 8080, NameResolver.new, :backend => Thin::Backends::PspServer)
