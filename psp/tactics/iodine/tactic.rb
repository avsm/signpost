#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

$:.unshift File.dirname(__FILE__)
require 'helper'

tactic = TacticHelper.new

tactic.when :local_ip do |helper, truths|
  # We don't want to setup tunnels to ourselves! That would be silly
  unless truths[:node_name][:value] == truths[:domain][:value] then
    ip = truths[:local_ip][:value]

    # provide_truth: TRUTH, VALUE, TTL, GLOBAL?
    # helper.provide_truth truths[:what][:value], ips, ttl, true
  end
  helper.recycle_tactic
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
