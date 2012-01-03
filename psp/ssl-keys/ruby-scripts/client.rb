require 'rubygems'
require 'openssl'
require 'socket'
require 'pp'

# Create a context for the connection
context = OpenSSL::SSL::SSLContext.new
# For verification we need to set a CA file

context.verify_mode = OpenSSL::SSL::VERIFY_PEER
context.ca_file = 'ca_cert.pem'

#certificate = OpenSSL::X509::Certificate.new File.read 'client_cert.pem'
#private_key = OpenSSL::PKey::RSA.new File.read 'client_private_key.pem'
#context.cert = certificate
#context.key = private_key

# Create the socket
tcp_socket = TCPSocket.new 'localhost', 5000
ssl_client = OpenSSL::SSL::SSLSocket.new tcp_socket, context
ssl_client.connect

pp ssl_client

ssl_client.puts "Hello server!"
puts ssl_client.gets
