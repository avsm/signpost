require 'rubygems'
require 'bundler/setup'
require 'zmq'
require 'pp'
require 'tactic_solver'

gem "json"
begin
  require "json/ext"
rescue LoadError
  $stderr.puts "C version of json (fjson) could not be loaded, using pure ruby one"
  require "json/pure"
end

# Name of the tactic solver node
solver_name = "supernode"

# -------------------------

# Don't buffer output (for debug purposes)
$stderr.sync = true

# Setup 0mq work queue
context = ZMQ::Context.new(1)
socket = context.socket(ZMQ::REP)
socket.bind("ipc://tactic_solver:5000")

# Create the tactic solver
tactic_solver = TacticSolver::Solver.new solver_name
ip_port = tactic_solver.get_ip_port

while true
  puts "Waiting for work"
  work = JSON.parse(socket.recv)

  # Shut down when the DNS server does
  if work["terminate"] then
    context.close
    socket.close
    exit 0
  end

  # We have real work to do...
  what = work["what"]
  user_info = work["user_info"]

  options = {:what => what, :solver => ip_port, :user_info => user_info}
  ip_question = TacticSolver::Question.new options do |truths|
    ips = []
    truths.to_a.each do |truth|
      truth_name, who, answer = truth
      answer.class == Array ? answer.each {|a| ips << a} : ips << answer
    end
    ips
  end

  ips = ip_question.answer

  reply = {
    :status => "OK",
    :ips => ips
  }
  socket.send reply.to_json
end

