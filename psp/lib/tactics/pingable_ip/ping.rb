#! /usr/bin/ruby

require 'rubygems'
require 'ping'
require 'bundler/setup'
require 'net/dns/resolver'
require 'tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when do |helper, truths|
  # We are waiting for: ip_for_domain@Destination
  waiting_for = "ip_for_domain@#{truths[:destination][:value]}"
  $stderr.puts "Waiting for #{waiting_for}"
  tactic.when waiting_for do |h, t|
    $stderr.puts "Got what I was waiting for :)"
    ip = t[waiting_for][:value]
    ip = ip.first if ip.class == Array
    helper.provide_truth truths[:what][:value], true, true if Ping.pingecho(ip, 10, 80)
    helper.terminate_tactic
  end
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
