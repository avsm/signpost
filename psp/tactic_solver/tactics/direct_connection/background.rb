#! /usr/bin/ruby

require 'rubygems' 
require 'daemons'
require 'socket'              

Daemons.daemonize

PORT = 16665
  
server = TCPServer.open PORT
loop do
  client = server.accept
  data = client.gets
  client.puts data
  client.close
end
