#! /usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'bundler/setup'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

module PubIp
  def self.get_ip helper, truths
    an_hour = 60*60
    public_ip = Net::HTTP.get('pingable.heroku.com', '/public_ip')
    helper.provide_truth "public_ip@#{truths[:node_name][:value]}", public_ip, an_hour, true

    EM.add_timer(50*60) do
      get_ip helper, truths
    end
  end
end

tactic.when do |helper, truths|
  PubIp.get_ip helper, truths
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
