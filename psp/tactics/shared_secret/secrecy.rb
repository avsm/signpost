#! /usr/bin/env ruby

require 'rubygems'
require 'digest/sha1'
require 'base64'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when :local_signpost_domain do |helper, truths|
  signpost_domain = truths[:local_signpost_domain][:value]
  truths[:resource][:value] =~ /shared_secret-([[:graph:]]*)/
  service = $1
  helper.log "Generating shared secret for #{service}"

  # FIXME: This should be based on a shared key of some sort!
  garb_secret = Digest::SHA1.hexdigest("key for #{signpost_domain} and service #{service}")
  secret = Base64.encode64(garb_secret).chomp

  a_year = 365 * 24 * 60 * 60
  helper.provide_truth truths[:what][:value], secret, a_year, true

  # Ready to generate more shared secrets :)
  helper.recycle_tactic
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
