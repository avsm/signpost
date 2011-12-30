require 'rubygems'
require 'bundler/setup'
require 'pp'
require 'lib/tactic_solver'

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

class SolvingServer < EventMachine::Connection
  def initialize ip_port
    @ip_port = ip_port
    @received_results = false
    super
  end

  def receive_data data
    unless data.chomp == "" then
      work = JSON.parse(data)

      # We have real work to do...
      what = work["what"]
      user_info = work["user_info"]
      options = {:what => what, :solver => @ip_port, :user_info => user_info}

      TacticSolver::Question.new options do |truths|
        @received_results = true
        results = []
        truths.to_a.each do |truth|
          truth_name, who, user_info, answer = truth
          answer.class == Array ? answer.each {|a| results << a} : results << answer
        end
        reply = {
          :status => "OK",
          :result => results,
          :what => what,
          :user_info => user_info
        }
        send_data "#{reply.to_json}\n"
      end

      EM.add_timer(30) do
        reply = {
          :status => "FAILED",
          :message => "Timeout"
        }
        send_data "#{reply.to_json}\n" unless @received_results
      end

      close_connection if work["terminate"]
    end
  end
end

EventMachine::run {
  # Create the tactic solver
  tactic_solver = TacticSolver::Solver.new solver_name
  EventMachine::start_server "127.0.0.1", 5000, SolvingServer, tactic_solver.ip_port
  puts "Started the server"
}
