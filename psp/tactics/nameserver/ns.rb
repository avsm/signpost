#! /usr/bin/env ruby

require 'rubygems'
require 'timeout'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module NSResolve
  def self.resolve domain, helper
    an_hour = 60*60
    resolver = Net::DNS::Resolver.new()
    res = Timeout::timeout(7) do
      resolver.send(domain, Net::DNS::NS)
    end
    res.answer.each do |answer|
      if answer.class == Net::DNS::RR::NS then
        return [answer.ttl, true]
      end
    end
    [an_hour, false]

  rescue Net::DNS::Resolver::NoResponseError
    helper.log "Didn't get a response from the DNS server..."
    [an_hour, false]

  rescue Errno::EPIPE
    helper.log "EPIPE error..."
    [an_hour, false]

  rescue Timeout::Error
    helper.log "Finding the name server timed out"
    [an_hour, false]
  end
end

tactic = TacticHelper.new

tactic.when do |helper, truths|
  domain = truths[:domain][:value] 
  ttl, is_nameserver = NSResolve::resolve domain, helper

  # provide_truth: TRUTH, VALUE, TTL, GLOBAL?
  helper.provide_truth truths[:what][:value], is_nameserver, ttl, true
  helper.recycle_tactic
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
