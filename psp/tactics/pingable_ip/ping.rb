#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when :ip_for_domain do |helper, truths|
  # We are waiting for: ip_for_domain@Destination
  ips = truths[:ip_for_domain][:value].first
  ip = ips.first
  result = `ping -q -c 1 #{ip}`
  if ($?.exitstatus == 0) then
    helper.provide_truth truths[:what][:value], true, 10, true
  end
  helper.terminate_tactic
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
