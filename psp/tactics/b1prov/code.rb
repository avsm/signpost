#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when :c, :d do |helper, truths|
  helper.provide_truth truths[:what][:value], true, 100, true
  helper.terminate_tactic  
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
