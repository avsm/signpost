#! /usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when do |helper, truths|
  packet = Net::DNS::Resolver.start(truths[:domain][:value])
  ips = []
  packet.each_address do |ip|
    ips << ip
  end
  # provide_truth: TRUTH, VALUE, CACHEABLE(boolean)
  helper.provide_truth truths[:what][:value], ips, true
  helper.terminate_tactic
  
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
