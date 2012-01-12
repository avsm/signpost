#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module Iodine
  def self.start_client helper, truths
    ten_minutes = 10 * 60

    password = truths[:iodined_password][:value]
    domain = truths[:domain][:value]

    # Start the iodined server
    iodine_cmd = "sudo iodine -f -P #{password} i.#{domain}" 
    helper.log "Issuing command to connect to iodine daemon on #{domain}: #{iodine_cmd}"
    deferrable = EventMachine::DeferrableChildProcess.open(iodine_cmd)

    helper.log "Tunnel setup. Notify client: #{d}"
    server_ip = truths[:iodined_ip][:value]
    helper.provide_truth "connectable_ip@#{truths[:domain][:value]}", server_ip, ten_minutes, false

    # Set the callbacks, so we can handle if the server shuts down.
    deferrable.callback do |d|
      # TODO: Should we tear down the channel again later?
      # FIXME: This might be called if the connection times out. Then what?
    end

    deferrable.errback do
      helper.log "Tunnel setup failed. Do something"
    end

    helper.recycle_tactic
  end
end

tactic = TacticHelper.new

# We need the local IP of the machine we are connecting to!
tactic.when do |helper, truths|
  unless truths[:node_name][:value] == truths[:domain][:value] then
    remote_signpost = truths[:domain][:value]
    helper.need_truth "iodined_running", {:domain => remote_signpost}

  else
    helper.log "We don't want to create a bridge to ourselves"
    helper.recycle_tactic

  end
end

tactic.when :iodined_running do |helper, truths|
  if truths[:iodined_running][:value] then
    remote_signpost = truths[:domain][:value]
    helper.need_truth "iodined_password", {:signpost => remote_signpost}
    helper.need_truth "iodined_ip", {:signpost => remote_signpost}
  else
    helper.log "IODINED is not running on the remote machine. Cannot setup connection."
    helper.recycle_tactic
  end
end

tactic.when :iodined_password, :iodined_ip do |helper, truths|
  Iodine.start_client helper, truths
end


# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
