#! /usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'net/dns/resolver'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when do |helper, truths|
  # This is the initial method...
  # Provide some daemon lemon pie
  helper.provide_truth "daemon@pie", "tastes less good", 0, true

  # We also want to observe changes in IP for domain
  helper.observe_truth "ip_for_domain"
end

# This method gets called each time there is a new
# ip_for_domain resource added to the tactic solver
# truth bag. It then subsequently requests that the
# ip gets pinged.
tactic.when :ip_for_domain do |helper, truths|
  destination = truths[:ip_for_domain][:destination]
  options = {:destination => destination}
  helper.need_truth "pingable_ip_for_domain", options
end

# This method gets called when the result of the ping
# is returned.
tactic.when :pingable_ip_for_domain do |helper, truths|
  if truths[:pingable_ip_for_domain][:value] then
    helper.log "Yeah! The domain was pingable!"
  else
    helper.log "Oh noes! The domain wasn't pingable!"
  end
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run