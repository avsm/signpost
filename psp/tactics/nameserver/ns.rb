#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module NSResolve
  def self.resolve domain
    an_hour = 60*60
    resolver = Net::DNS::Resolver.new()
    res = resolver.send(domain, Net::DNS::NS)
    res.answer.each do |answer|
      if answer.class == Net::DNS::RR::NS then
        return [answer.ttl, true]
      end
    end
    [an_hour, false]

  rescue Net::DNS::Resolver::NoResponseError, Errno::EPIPE
    [an_hour, false]
  end
end

tactic = TacticHelper.new

tactic.when do |helper, truths|
  domain = truths[:domain][:value] 
  helper.log "Domain: #{domain}"
  ttl, is_nameserver = NSResolve::resolve domain

  # provide_truth: TRUTH, VALUE, TTL, GLOBAL?
  helper.provide_truth truths[:what][:value], is_nameserver, ttl, true
  helper.recycle_tactic
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
