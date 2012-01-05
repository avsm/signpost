require 'rubygems'
require 'bundler/setup'
require 'eventmachine'

class IodineClient < EventMachine::Connection
  def post_init
    puts "in post init"
    send "status?"
    send "password?"
  end
  
  def receive_data data
    data.split("\n").each do |d|
      puts "Got: #{data}"
    end
  end

  # When the remote end closes the connection
  def unbind
    puts "unbind"
    EventMachine::stop_event_loop
  end  

private
  def send data
    send_data "#{data}\n"
  end
end
  
EventMachine::run do
  EventMachine::connect_unix_domain("/tmp/signpost-iodined.sock", IodineClient)
end
