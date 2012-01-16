#! /usr/bin/env ruby

require 'rubygems'
require 'socket'
require 'Timeout'
require 'bundler/setup'
require 'lib/tactic_solver/tactic_helper'

tactic = TacticHelper.new

tactic.when do |helper, truths|
  if truths[:resource][:value] == "incoming_connection" then
    helper.log "Someone wants to try to connect to us"

    port = truths[:port][:value]
    server = TCPServer.open(port)  
    helper.provide_truth "listening_on_port@#{truths[:destination][:value]}", true, 0, false

    begin
      value = Timeout::timeout(10) do
        client = server.accept       
        sleep(1)
        client.close
      end

    rescue Timeout::Error 
      helper.log "Incoming TCP port closed... No connection"

    ensure
      helper.recycle_tactic

    end

  elsif truths[:resource][:value] == "direct_connection" then
    helper.log "We want to try to connect to someone"
    helper.observe_truth "listening_on_port", {:domain => truths[:domain][:value]}
    helper.need_truth "incoming_connection", {:destination => truths[:destination][:value], :signpost => truths[:domain][:value]}
    helper.need_truth "public_ip", {:domain => truths[:domain][:value]}

  else
    helper.log "Something requested that I don't know how to deal with"

  end
end

tactic.when :public_ip, :listening_on_port do |helper, truths|
  begin
    host = truths[:public_ip][:value]
    port = truths[:port][:value]
    helper.log "Trying to connect to #{host}:#{port}"

    Timeout::timeout(3) do
      s = TCPSocket.open(host, port)
      helper.provide_truth truths[:what][:value], true, 10, true
      s.close     
    end

  rescue Timeout::Error
    helper.provide_truth truths[:what][:value], false, 10, true

  ensure
    helper.recycle_tactic

  end

end

# We need to initialize the tactic, otherwise nothing will ever happen
tactic.run
