#! /usr/bin/env ruby

require 'rubygems'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module Iodined
  def self.gen_random_num
    rand(256)
  end

  def self.gen_random_ip
    "10.#{gen_random_num}.#{gen_random_num}.1"
  end

  def self.start_server helper, truths
    a_day = 24 * 60 * 60
    ten_minutes = 10 * 60

    password = truths[:"shared_secret-iodined"][:value]
    domain = truths[:node_name][:value]
    ip = gen_random_ip
    dns_forwarding_port = 5353

    # Start the iodined server
    iodined_cmd = "sudo iodined -f -c -b #{dns_forwarding_port} -P #{password} #{ip} io.#{domain}" 
    deferrable = EventMachine::DeferrableChildProcess.open(iodined_cmd)

    helper.provide_truth "iodined_ip@#{truths[:node_name][:value]}", 
        ip, a_day, true

    helper.provide_truth "iodined_running@#{truths[:node_name][:value]}", 
        true, a_day, true

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
# - Check if we are the main cloud signpost, if so, then there is no iodined
#   running, so we cannot do any name resolutions. If we are, then start
#   iodined.
# - Choose a random IP range to create an Iodined daemon on, and hope it
#   doesn't clash :)
# - Setup iodined
# - Broadcast to the world, that the iodined IP of this machine is X.
tactic.when do |helper, truths|
  node_name = truths[:node_name][:value]
  helper.need_truth "local_signpost_domain", {:domain => node_name}
  helper.need_truth "shared_secret-iodined", {:domain => node_name}
end

tactic.when :local_signpost_domain, "shared_secret-iodined" do |helper, truths|
  if truths[:local_signpost_domain][:value] == truths[:node_name][:value] then
    # We are the cloudy signpost! In otherwords, we really need to run iodined,
    # otherwise no other machine can access our DNS since it is tunnelling
    # through iodined
    helper.log "Powering up IODINED"
    Iodined.start_server helper, truths

  else
    helper.log "We are not the cloudy nameserver. We therefore do not setup iodined for now"
    a_day = 24 * 60 * 60
    helper.provide_truth "iodined_running@#{truths[:node_name][:value]}", 
        false, a_day, true
  end
end


# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
