#! /usr/bin/env ruby

# This daemon starts on system startup.
# It needs to run as root.
# It will start the iodine server, and can communicate with the tactic solver
# through a simple protocol.

require 'rubygems'
require 'eventmachine'


module Iodined
  def self.generate_password
    o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
    (0..50).map{ o[rand(o.length)]  }.join
    "seb"
  end

  class IodineServer < EventMachine::Connection
    def initialize password
      @_password = password
      super
    end

    def receive_data data
      data.split("\n").each do |d|
        send "password:#{@_password}" if d == "password?"
        send "status:#{@@status}" if d == "status?"
        send "port:#{@@port}" if d == "port?"
        if d =~ /connect_me:([[:graph:]]*):([[:graph:]]*)/ then
          ip = $1
          password = $2
          connect_to_tunnel ip, password
        end
      end
    end

    def unbind
      puts "Client disconnected"
    end

  private
    def send data
      send_data "#{data}\n"
    end

    def connect_to_tunnel ip, password
      puts "Connecting to #{ip} with password #{password}"
    end
  end
end

EM.run do
  password = Iodined::generate_password
  @@status = "starting"
  @@port = 53

  EventMachine::start_unix_domain_server("/tmp/signpost-iodined.sock", Iodined::IodineServer, password)

  # Start the iodined server
  iodined_cmd = "sudo iodined -f -p #{@@port} -P #{password} 10.0.0.1 fd.com" 
  deferrable = EventMachine::DeferrableChildProcess.open(iodined_cmd)

  # # Set the callbacks, so we can handle if the server shuts down.
  deferrable.callback do
    @@status = "running"
  end
  deferrable.errback do
    @@status = "error"
  end
end
