require 'rubygems'
require 'bundler/setup'
require 'rubydns'
require 'timeout'
require 'socket'

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

# ip and port this DNS server binds to
ip = "0.0.0.0"
port = 5300

# -----------------
# Don't buffer output (for debug purposes)
$stderr.sync = true

# Start the RubyDNS server
dns_server = RubyDNS::run_server(:listen => [[:udp, ip, port]]) do

  # Default DNS handler
  otherwise do |transaction|
    # key = [transaction.name, transaction.resource_class]
    # transaction.respond!(HARU_A)

    # We are trying to resolve an IP
    request = {
      :what => "ip_for_domain@#{transaction.name}",
      :user_info => @@user_info
    }

    solver_ip = '127.0.0.1'
    port = 5000
    s = TCPSocket.open(solver_ip, port)
    s.puts "#{request.to_json}"
    reply = JSON.parse(s.gets)
    s.close

    if reply["status"] == "OK" then
      ips = reply["ips"]
      ips.each do |ip|
        transaction.respond!(ip)
      end
    end

  end
end

# Let the tactic solver know that it should terminate
@@tactic_solver.send({:terminate => true}.to_json)
@@tactic_solver.close
