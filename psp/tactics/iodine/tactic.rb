#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module Iodine
  def self.start_client helper, truths
    a_day = 24 * 60 * 60
    ten_minutes = 10 * 60

    password = truths[:iodined_password][:value]
    domain = truths[:domain][:value]
    ip_address = truths[:local_ips][:value].first

    # Start the iodined server
    iodine_cmd = "sudo iodine -P #{password} #{ip_address} #{domain}" 
    helper.log iodine_cmd
    deferrable = EventMachine::DeferrableChildProcess.open(iodine_cmd)

    # Set the callbacks, so we can handle if the server shuts down.
    deferrable.callback do |d|
      helper.log "Tunnel setup. Notify client"
      helper.provide_truth "connectable_ip@#{truths[:domain][:value]}", "10.0.0.1", ten_minutes, false

      # TODO: Should we tear down the channel again later?

      # EM.add_timer(1) do
      #   helper.recycle_tactic
      # end
    end

    deferrable.errback do
      helper.log "Tunnel setup failed. Do something"
      helper.recycle_tactic
    end
  end
end

tactic = TacticHelper.new

# We need the local IP of the machine we are connecting to!
tactic.when do |helper, truths|
  unless truths[:node_name][:value] == truths[:domain][:value] then
    remote_signpost = truths[:domain][:value]

    helper.log "Requesting that we need a truth (local_ips and iodined_password)"
    helper.need_truth "local_ips", {:signpost => remote_signpost}
    helper.need_truth "iodined_password", {:signpost => remote_signpost}

  else
    helper.log "We don't want to create a bridge to ourselves"
    helper.recycle_tactic

  end
end

tactic.when :local_ips, :iodined_password do |helper, truths|
  Iodine.start_client helper, truths
end


# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
