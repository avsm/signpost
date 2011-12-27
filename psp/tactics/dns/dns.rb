#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when do |helper, truths|
  packet = Net::DNS::Resolver.start(truths[:domain][:value])
  ips = []
  packet.each_address do |ip|
    ips << ip
  end
  # provide_truth: TRUTH, VALUE, TTL, GLOBAL?
  helper.provide_truth truths[:what][:value], ips, 100, true
  helper.recycle_tactic
  
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
