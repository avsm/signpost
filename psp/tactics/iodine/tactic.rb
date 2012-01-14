#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module Iodine
  def self.start_client helper, truths
    ten_minutes = 10 * 60

    password = truths[:shared_secret-iodine][:value]
    domain = truths[:domain][:value]

    # Start the iodined server
    iodine_cmd = "sudo iodine -f -P #{password} io.#{domain}" 
    helper.log "Issuing command to connect to iodine daemon on #{domain}: #{iodine_cmd}"
    deferrable = EventMachine::DeferrableChildProcess.open(iodine_cmd)

    helper.log "Tunnel setup. Notify client: #{d}"
    # FIXME: Get ip from output
    helper.provide_truth "connectable_ip@#{truths[:domain][:value]}", "10.0.0.1", ten_minutes, false

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
tactic.when "shared_secret-iodined", :local_signpost_domain do |helper, truths|
  unless truths[:node_name][:value] == truths[:local_signpost_domain][:value] then
    unless truths[:node_name][:value] == truths[:domain][:value] then
      Iodine.start_client helper, truths

    else
      helper.log "We don't want to create a bridge to ourselves"
      helper.recycle_tactic

    end

  else
    # We are the central signpost. We really don't want to setup a connection
    # to any one using iodined!
    helper.recycle_tactic

  end
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
