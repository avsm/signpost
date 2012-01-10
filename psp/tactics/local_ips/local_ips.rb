#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'socket'
require 'lib/tactic_solver/tactic_helper'

module IpAddress
  def self.local_ip
    # turn off reverse DNS resolution temporarily
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  

    UDPSocket.open do |s|
      s.connect '64.233.187.99', 1
      s.addr.last
    end
  ensure
    Socket.do_not_reverse_lookup = orig
  end
end
tactic = TacticHelper.new

tactic.when do |helper, truths|
  # Since we are using ruby 1.8.7 we don't have Socket.ip_address_list
  # so we need to resort to a roundabout kind of solution

  ten_minutes = 10*60
  own_ips = [IpAddress.local_ip]

  # provide_truth: TRUTH, VALUE, TTL, GLOBAL?
  helper.provide_truth truths[:what][:value], own_ips, ten_minutes, true
  helper.recycle_tactic
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
