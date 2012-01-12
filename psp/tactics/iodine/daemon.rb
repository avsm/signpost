#! /usr/bin/env ruby

require 'rubygems'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module Iodined
  def self.generate_password
    o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten
    (0..50).map{ o[rand(o.length)]  }.join
    "seb"
  end

  def self.gen_random_ip
    "10.#{get_random_num}.#{get_random_num}.1"
  end

  def self.get_random_num
    Random.new.rand(256)
  end

  def self.start_server helper, truths
    a_day = 24 * 60 * 60
    ten_minutes = 10 * 60

    password = Iodined::generate_password
    domain = truths[:node_name][:value]
    ip = get_random_ip

    # Start the iodined server
    iodined_cmd = "sudo iodined -f -c -P #{password} #{ip} #{domain}" 
    helper.log iodined_cmd
    deferrable = EventMachine::DeferrableChildProcess.open(iodined_cmd)

    helper.provide_truth "iodined_ip@#{truths[:node_name][:value]}", 
        ip, a_day, true

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

# Tactic:
# - Check if our name is publicly resolvable as an NS record
# - Check that that name points to us through an A record
# - Choose a random IP range to create an Iodined daemon on, and hope it
#   doesn't clash :)
# - Setup iodined
# - Broadcast to the world, that the iodined IP of this machine is X.
tactic.when do |helper, truths|
  # We want to check if our name can be resolved as an NS record
  helper.need_truth "is_nameserver", {:domain => truths[:node_name][:value]}
end

tactic.when :is_nameserver do |helper, truths|
  if truths[:is_nameserver][:value] then
    helper.log "Is nameserver, will setup iodined"
    Iodined.start_server helper, truths
  else
    helper.log "Is NOT nameserver, will NOT setup iodined"
  end
end


# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
