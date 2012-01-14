#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module OpenVPN
  def self.setup_client2
    client2_cmd = "sudo iodined -f -c -P #{password} #{ip} #{domain}" 
    deferrable = EventMachine::DeferrableChildProcess.open(client2_cmd)

    # Provide my IP

    # helper.provide_truth "iodined_ip@#{truths[:node_name][:value]}", 
    #     ip, a_day, true

    deferrable.errback do
      # Say if it failed...
      #
      # helper.provide_truth "iodined_running@#{truths[:node_name][:value]}", 
      #     false, 24*60*60, true
    end

  end

  def self.setup_client1
    client1_cmd = "sudo iodined -f -c -P #{password} #{ip} #{domain}" 
    deferrable = EventMachine::DeferrableChildProcess.open(client1_cmd)

    # helper.provide_truth "iodined_ip@#{truths[:node_name][:value]}", 
    #     ip, a_day, true
    
    deferrable.errback do
      # Didn't work to setup the tunnel. What to do?
    end
  end
end

tactic = TacticHelper.new

# This method is called if we want to setup a VPN connetion to a remote system,
# but also if someone wants to connect to us.
# - connectable_ip@([[:graph:]]*)
# - receiving_vpn_tunnel@([[:graph:]]*)
tactic.when do |helper, truths|
  helper.log "We are in the OpenVPN tactic. This was requested: #{truths[:what][:value]}"
  if truths[:resource][:value] == "connectable_ip" then
    helper.log "We want to setup a VPN connection to #{truths[:domain][:value]}"

    # We need to find a VPN server in our network
    helper.need_truth "openvpn_server"
  end

  if truths[:resource][:value] == "receiving_vpn_tunnel" then
    helper.log "Someone wants to connect to us."
  end

  helper.recycle_tactic
end

tactic.when :openvpn_server do |helper, truths|
  if truths[:openvpn_server][:value] then
    helper.need_truth "openvpn_server_port", {:domain => truths[:openvpn_server][:domain]}
  else
    helper.log "Got an OpenVPN server node, but it isn't running..."
  end
end

tactic.when :openvpn_server_port do |helper, truths|
  port = truths[:openvpn_server_port][:value]
  helper.need_truth "receiving_vpn_tunnel", {
    :domain => truths[:openvpn_server_port][:domain],
    :signpost => truths[:what][:domain]
  }
end

tactic.when :receiving_vpn_tunnel do |helper, truths|
  # The remote IP is
  ip = truths[:receiving_vpn_tunnel][:value]
  helper.log "Got remote receiving tunnel ip #{ip}"
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
