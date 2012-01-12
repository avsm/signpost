#! /usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'bundler/setup'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

module Pingable
  def self.pingable? helper, truths
    an_hour = 60*60
    pingable = Net::HTTP.get('pingable.heroku.com', '/pingable') == "true" ? true : false
    helper.provide_truth "remotely_pingable@#{truths[:node_name][:value]}", pingable, an_hour, true

    EM.add_timer(50*60) do
      pingable? helper, truths
    end
  end
end

tactic.when do |helper, truths|
  Pingable.pingable? helper, truths
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
