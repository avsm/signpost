#! /usr/bin/env ruby

require 'rubygems'
require 'lib/tactic_solver/tactic_helper'

$:.unshift File.dirname(__FILE__)
require 'helper'

tactic = TacticHelper.new

tactic.when do |helper, truths|
  begin
    EventMachine::connect_unix_domain("/tmp/signpost-iodined.sock", IodineDaemon, helper)
  rescue RuntimeError => e
    helper.log "The IODINED server is not running on this system. " \
        + "#{truths[:node_name][:value]} will not be able to accept incoming IP over DNS connections"
  end
end
tactic = TacticHelper.new

tactic.when do |helper, truths|
  begin
    EventMachine::connect_unix_domain("/tmp/signpost-iodined.sock", IodineDaemon, helper)
  rescue RuntimeError => e
    helper.log "The IODINED server is not running on this system. " \
        + "#{truths[:node_name][:value]} will not be able to accept incoming IP over DNS connections"
  end
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
