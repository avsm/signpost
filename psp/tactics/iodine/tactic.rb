#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module Iodine
  def self.start_client helper, truths
    a_day = 24 * 60 * 60

    password = truths[:"shared_secret-iodined"][:value]
    domain = truths[:domain][:value]

    server_ip = "172.16.0.1" # gen_random_ip
    helper.provide_truth truths[:what][:value], server_ip, a_day, false

    # Start the iodined server
    iodine_cmd = "sudo iodine -f -P #{password} i.#{domain}" 
    helper.log "Issuing command to connect to iodine daemon on #{domain}: #{iodine_cmd}"

    # deferrable = EventMachine::DeferrableChildProcess.open(iodine_cmd)
    # deferrable.errback do
    #   helper.log "Tunnel setup failed. Do something"
    # end

    helper.recycle_tactic
  end
end

tactic = TacticHelper.new

# We need the local IP of the machine we are connecting to!
tactic.when :"shared_secret-iodined", :local_signpost_domain do |helper, truths|
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
