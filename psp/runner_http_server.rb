#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup' # To ensure the version installed by bundler is used
require 'sinatra'
require 'thin'
require 'scanf'
require 'timeout'
require 'http_server/psp_backend'

gem "json"

begin
  require "json/ext"
rescue LoadError
  $stderr.puts "C version of json (fjson) could not be loaded, using pure ruby one"
  require "json/pure"
end

module Signpost 
  # We are dealing with JSON, so set the right content type
  class PSPFrontEnd < Sinatra::Base
    configure do
      mime_type :json, "application/json"
    end

    before do
      content_type :json
    end

    # -----------------------------------------------
    # -----------------------------------------------
    # Signpost Protocol V1
    # All requests are prefixed with /v1/
    # -----------------------------------------------

    # For use by the Client Resolver
    # Resolve an address to an ip
    get "/v1/address/:domain" do
      user_info = request.env["user_info"]
      domain = params[:domain]
      return Solver::resolve "ip_for_domain@#{domain}", user_info
    end

    # Get the signposts that exist as part of a signpost domain
    get "/v1/signposts" do
      # TODO: get list of signposts from somewhere.
      [{:ip => "127.0.0.1", :port => 8080}].to_json
    end

    # For use by signposts
    # Get the key of a device
    get "/v1/keys/:device" do
      user_info = request.env["user_info"]
      device = params[:device]
      # TODO: Implement key_for_device tactic
      return Solver::resolve "key_for_device@#{device}", user_info
    end

    # -----------------------------------------------
    # DEPRECATED access patterns
    # -----------------------------------------------
    
    # We are deprecating the use of the unversioned interface
    # Instead, use /v1/address/:url
    get "/address/:domain" do
      user_info = request.env["user_info"]
      domain = params[:domain]
      reply = JSON.parse(Solver::resolve "ip_for_domain@#{domain}", user_info)
      reply[:warning] = "/address is deprecated. Use /v1/address instead"
      reply.to_json
    end
  end

  module Solver
    def self.resolve what, user_info
      # IP and PORT of the solver
      solver_ip = '127.0.0.1'
      port = 5000

      request = {
        :what => what,
        :user_info => user_info
      }

      # We are trying to resolve an IP
      s = TCPSocket.open(solver_ip, port)
      s.puts "#{request.to_json}"
      reply = s.gets
      s.close

      return reply
    end

    def self.resolve_domain domain, user_info
      resolve "ip_for_domain@#{domain}", user_info
    end
  end
end

Thin::Server.start('0.0.0.0', 8080, Signpost::PSPFrontEnd.new, :backend => Signpost::Backends::PspServer)
