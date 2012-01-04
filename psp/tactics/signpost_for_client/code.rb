#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

module SignpostFinder
  def self.resolve domain
    resolver = Net::DNS::Resolver.new()
    req_str = "_signpost._tcp.#{domain.join(".")}"
    packet = Net::DNS::Packet.new(req_str, Net::DNS::SRV)

    answers = []
    resolver.send(packet).answer.each do |rr|
      # We got an SRV packet, hopefully :)
      host = rr.host
      # Remove trailing 'dot' if present
      host_array = host.split("")
      host = host_array[0...(host_array.size-1)].join("") if host_array.last == "."

      answers << [host, rr.port]
    end

    answers
  end
end

tactic = TacticHelper.new

tactic.when do |helper, truths|
  # This is some of the state we want to return
  signposts = []
  ttl = 24 * 60 * 60
  global = true

  # Find singposts if any
  domain = truths[:domain][:value]
  domain_parts = domain.split "."
  0.upto(domain_parts.size-2) do |n|
    signposts << (SignpostFinder.resolve domain_parts[n..(domain_parts.size)])
  end

  # This truth can be cached, and is global
  helper.provide_truth truths[:what][:value], signposts.flatten, ttl, global
  helper.recycle_tactic  
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
