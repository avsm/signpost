#! /usr/bin/env ruby

require 'rubygems'
require 'lib/tactic_solver/tactic_helper'

module Iodined
  def self.generate_password
    o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
    (0..50).map{ o[rand(o.length)]  }.join
    "seb"
  end

  def self.start_server helper, truths
    a_day = 24 * 60 * 60
    ten_minutes = 10 * 60

    password = Iodined::generate_password
    domain = truths[:node_name][:value]

    # Start the iodined server
    iodined_cmd = "sudo iodined -f -P #{password} 10.0.0.1 #{domain}" 
    deferrable = EventMachine::DeferrableChildProcess.open(iodined_cmd)

    helper.provide_truth "iodined_running@#{truths[:node_name][:value]}", 
        true, a_day, true

    helper.provide_truth "iodined_password@#{truths[:node_name][:value]}",
        password, a_day, true
    
    deferrable.errback do
      helper.log "Couldn't start the IODINED server. Trying again in 10 minutes"
      helper.provide_truth "iodined_running@#{truths[:node_name][:value]}", 
          false, 24*60*60, true

      EM.add_timer(ten_minutes) do
        helper.log "Trying again to start the IODINED server"
        Iodined.start_server helper, truths
      end
    end
  end
end

tactic = TacticHelper.new

tactic.when do |helper, truths|
  Iodined.start_server helper, truths
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
