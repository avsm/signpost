require 'rubygems'
require 'openssl'
require 'socket'
require 'pp'

# Create a context for the connection
context = OpenSSL::SSL::SSLContext.new
context.verify_mode = OpenSSL::SSL::VERIFY_CLIENT

## This is what is done on the client
# For verification we need to set a CA file
# context.ca_file = 'ca_cert.pem'
# context.verify_mode = OpenSSL::SSL::VERIFY_PEER

certificate = OpenSSL::X509::Certificate.new File.read 'server_cert.pem'
private_key = OpenSSL::PKey::RSA.new File.read 'server_private_key.pem'

context.cert = certificate
context.key = private_key

context.ca_file = 'ca_cert.pem'

# Create the socket
tcp_server = TCPServer.new 5000
ssl_server = OpenSSL::SSL::SSLServer.new tcp_server, context

puts "waiting for connections"
loop do
  ssl_connection = ssl_server.accept
  client_cert = ssl_connection.cert
  pp ssl_connection

  data = ssl_connection.gets

  response = "I got #{data.dump}"
  puts response

  ssl_connection.puts response
  ssl_connection.close
end
