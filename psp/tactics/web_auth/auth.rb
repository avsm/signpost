#! /usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when :web_auth_url do |helper, truths|
  client = truths[:user][:value]
  resource = truths[:domain][:value]
  web_auth_url = truths[:web_auth_url][:value].first

  uri = URI.parse(URI.encode(web_auth_url))
  http = Net::HTTP.new(uri.host, uri.port)
  data = ({:resource => resource, :client => client}).to_json
  request = Net::HTTP::Post.new(uri.request_uri)
  request.body = data
  response = http.request(request)
  answer = response.body == "approve" ? true : false

  # provide_truth: TRUTH, VALUE, TTL, GLOBAL?
  helper.provide_truth truths[:what][:value], answer, 100, false
  helper.terminate_tactic
  
end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
