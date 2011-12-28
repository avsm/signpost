#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when do |helper, truths|
  helper.provide_truth truths[:what][:value], "tastes good", 0, true
  helper.recycle_tactic
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run