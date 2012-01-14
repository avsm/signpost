#! /usr/bin/env ruby

require 'rubygems'
require 'lib/tactic_solver/tactic_helper'

module OpenVPN
  def self.start_server helper, truths
    one_day = 24*60*60

    openvpn_cmd = "sudo ./start.sh" 
    deferrable = EventMachine::DeferrableChildProcess.open(openvpn_cmd)

    helper.provide_truth "openvpn_server@#{truths[:node_name][:value]}", 
        true, a_day, true
    
    helper.provide_truth "openvpn_server_port@#{truths[:node_name][:value]}", 
        1194, a_day, true

    deferrable.errback do
      helper.log "Couldn't start the OpenVPN server. Trying again in 10 minutes"
      helper.provide_truth "openvpn_server@#{truths[:node_name][:value]}", 
          false, 24*60*60, true

      EM.add_timer(ten_minutes) do
        helper.log "Trying again to start the OpenVPN server"
        OpenVPN.start_server helper, truths
      end
    end

    EM.add_timer(one_day) do
      start_server helper, truths
    end
  end
end

tactic = TacticHelper.new

# Tactic, we only want to run a OpenVPN server on a globally accessible machine
# - We need our IP
# TODO: - We want to see if we can receive UDP packets on port 1194
tactic.when do |helper, truths|
  # We want to check if our name can be resolved as an NS record
  helper.log "Executing default case in openVPN tactic"
  helper.need_truth "remotely_pingable", {:domain => truths[:node_name][:value]}
end

tactic.when :remotely_pingable do |helper, truths|
  return unless truths[:remotely_pingable][:signpost] == truths[:node_name][:value]

  if truths[:remotely_pingable][:value] then
    helper.log "Is remotely pingable, will start OpenVPN server"
    OpenVPN.start_server helper, truths
  else
    helper.log "Is NOT remotely pingable, will NOT start OpenVPN server on this node"
  end
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
