#! /usr/bin/ruby

require 'rubygems'
require 'socket' 
require 'timeout'

return "FAILURE" if ARGV.size < 2

PORT = 16665
interface, host = ARGV[0], ARGV[1]

def run_test to, &block
  s = TCPSocket.open(to, PORT)
  yield s
end

def one_way_time start_time, end_time
  diff = (1000 * (end_time - start_time)).to_i / 2
  diff == 0 ? 1 : diff
end

latency = 0
bandwidth = 0
overhead = 0
ttl = 60

begin
  Timeout::timeout(2*60) do
    run_test host do |s|
      # ping pong for latency
      time_start = Time.now.to_i
      s.puts "pingpong"
      s.gets
      time_stop = Time.now.to_i
      ping_pong_time = one_way_time time_start, time_stop
      latency = ping_pong_time
    end

    run_test host do |s|
      # bandwidth data
      data = (1.upto(1_000).each.map { "****" }).flatten.to_s
      time_start = Time.now
      s.puts data
      s.gets
      time_stop = Time.now
      bandwidth_time = one_way_time time_start, time_stop
      bytes = data.bytes.count
      bandwidth = bytes / bandwidth_time
    end
  end

  puts "SUCCESS #{latency} #{bandwidth} #{overhead} #{ttl}"

rescue Timeout::Error
  puts "FAILURE"

end
