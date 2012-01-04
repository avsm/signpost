#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module DNSResolve
  def self.resolve domain
    resolver = Net::DNS::Resolver.new()
    data = (self.do_it resolver, domain).flatten
    min_ttl = nil
    ips = []
    data.each do |d|
      if d[:ttl] then
        min_ttl = d[:ttl] unless min_ttl
        min_ttl = d[:ttl] if d[:ttl] < min_ttl        
      end
      ips << d[:ip]
    end
    [min_ttl, ips.uniq]
  end

  def self.do_it resolver, domain
    res = resolver.send(domain)
    answers = []
    res.answer.each do |answer|
      if answer.class == Net::DNS::RR::CNAME then
        answers << (self.do_it resolver, answer.value)
      else
        answers << {
          :ip => answer.address.to_s,
          :ttl => answer.ttl
        }
      end
    end
    answers
  end
end

tactic = TacticHelper.new

tactic.when do |helper, truths|
  domain = truths[:domain][:value] 
  ttl, ips = DNSResolve::resolve domain

  # provide_truth: TRUTH, VALUE, TTL, GLOBAL?
  helper.provide_truth truths[:what][:value], ips, ttl, true
  helper.recycle_tactic
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
