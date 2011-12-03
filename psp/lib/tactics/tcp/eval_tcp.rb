#! /usr/bin/ruby

require 'rubygems'
require 'socket'
require 'tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when do |helper, truths|
  if truths[:resource][:value] == "tcp_in" then
    begin
      s = TCPServer.open truths[:port][:value]
      s.close
      # Could open a listening port
      helper.provide_truth truths[:what][:value], true, true

    rescue Errno::EACCES
      # Failed at opening port in
      helper.provide_truth truths[:what][:value], false, true
      
    end
    # We have done our work, so we can now terminate the tactic
    helper.terminate_tactic

  elsif truths[:resource][:value] == "tcp_out" then
    
    # TODO: Implement something useful here...
    
    # We have done our work, so we can now terminate the tactic
    helper.terminate_tactic

  end
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
