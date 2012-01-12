#! /usr/bin/env ruby

require 'rubygems'
require 'lib/tactic_solver/tactic_helper'

module OpenVPN
  def self.start_server helper, truths
    one_day = 24*60*60
    helper.provide_truth "openvpn_server@#{truths[:node_name][:value]}", true, one_day, true

    EM.add_timer(one_day) do
      start_server helper, truths
    end
  end
end

tactic = TacticHelper.new

# Tactic, we only want to run a OpenVPN server on a globally accessible machine
# - We need our IP
# - We 
tactic.when do |helper, truths|
  # We want to check if our name can be resolved as an NS record
  helper.need_truth "remotely_pingable", {:domain => truths[:node_name][:value]}
end

tactic.when :remotely_pingable do |helper, truths|
  if truths[:remotely_pingable][:value] then
    helper.log "Is remotely pingable, will start OpenVPN server"
    OpenVPN.start_server helper, truths
  else
    helper.log "Is NOT remotely pingable, will NOT start OpenVPN server on this node"
  end
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
