require 'rubygems'
require 'bundler/setup'
require 'rubydns'
require './dnser'
require './dns_server_overrides'

dns_er = DNSEr.new

RubyDNS::run_server(:listen => [[:tcp, "0.0.0.0", 5300]]) do

  # Match requests to list the available signposts
  match(/^_signpost._tcp\.(.*)/, :SRV) do |match, transaction|
    uri = match[1]
    dns_er.answer_signpost_query transaction.answer, uri
  end

  # Returns the public-key of a local device
  match(/^signpost_key\.(.*)/, :TXT) do |match, transaction|
    device = match[1]
    dns_er.answer_key_query transaction.answer, device
  end

  # Return a signpost resource, if it is allowed for the requesting client
  # A ticket for accessing the resource is also returned
  match(/^signpost_resource\.(.*)\._\.(.*)/, :TXT) do |match, transaction|
    id = match[1]
    resource = match[2]
    dns_er.answer_resource_query transaction.answer, resource, id
  end

  # Default DNS handler
  otherwise do |transaction|
    # We don't deal with non-signpost requests at the moment
    puts "Didn't match the transaction: #{transaction.inspect}"
    false
    # transaction.passthrough!($R)
  end

end
