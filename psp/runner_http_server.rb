require 'thin'
require 'rubygems'
require 'scanf'
require 'timeout'
require 'zmq'


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

context = ZMQ::Context.new(1)
@@tactic_solver = context.socket(ZMQ::REQ)
@@tactic_solver.connect("ipc://tactic_solver:5000")


class NameResolver

		def initialize 
  end

  def call(env)
    request = Rack::Request.new(env)
    puts env.inspect
    name = env['REQUEST_PATH'].scan(/[a-zA-Z\.]+/)
    # We are trying to resolve an IP
    request = {
      :what => "ip_for_domain@#{name[1]}",
      :user_info => @@user_info
    }

    @@tactic_solver.send(request.to_json)
    body = [(@@tactic_solver.recv)]
    [
      200,
      { 'Content-Type' => 'application/json' },
      body
    ]
  end
end

Thin::Server.start('0.0.0.0', 8080) do
  use Rack::CommonLogger
  map '/address/' do
    run NameResolver.new()
  end
  map '/files' do
    run Rack::File.new('.')
  end
end


# Let the tactic solver know that it should terminate
@@tactic_solver.send({:terminate => true}.to_json)
@@tactic_solver.close
context.close
