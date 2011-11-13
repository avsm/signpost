require 'rubygems'
require 'bundler/setup'
require 'json'
require 'open-uri'
require 'net/dns/resolver'

module Signpost
  class Resolver
    Defaults = {
      :nameserver => "127.0.0.1",
      :port => 5300,
      :retries => 1,
      :use_tcp => true
    }

    def initialize(options = {})
      conf = Defaults.merge options
      @resolver = Net::DNS::Resolver.new(:nameservers => conf[:nameserver],
                                         :port => conf[:port],
                                         :retry => conf[:retries],
                                         :use_tcp => conf[:use_tcp]
                                        )
    end

    def get_key id
      req_str = "signpost_key.#{id}"
      answers = resolve Net::DNS::Question.new(req_str, Net::DNS::TXT)
      answers.each do |answer|
        puts "Key for #{id}: #{answer["key"]}"
      end
      puts ""
      answers
    end

    def get_signpost id
      req_str = "_signpost._tcp.#{id}"
      answers = resolve Net::DNS::Question.new(req_str, Net::DNS::SRV)
      answers.each do |answer|
        puts "Signpost for #{id}:\n\t#{answer[:host]}:#{answer[:port]}" \
            + "\n\tweight:#{answer[:weight]}\n\tpriority:#{answer[:priority]}"
      end
      puts ""
      answers
    end

    def get_resource id, resource
      req_str = "signpost_resource.#{id}._.#{resource}"
      answers = resolve Net::DNS::Question.new(req_str, Net::DNS::TXT)
      answers.each do |answer|
        puts "Resource: #{id}:\n\t" \
            + "ip: #{answer["ip"]}\n\t" \
            + "port: #{answer["port"]}\n\t" \
            + "symmetric key: #{answer["key"]}\n\t" \
            + "Ticket:\n\t\t" \
            + "issuer: #{answer["issuer"]}\n\t\t" \
            + "client: #{answer["client"]}\n\t\t" \
            + "expires: #{answer["expires"]}\n\t\t" \
            + "resource_key: #{answer["resource_key"]}"

      end
      puts ""
      answers
    end

    private
    def resolve request
      packet = Net::DNS::Packet.new("kle.io", Net::DNS::A)
      packet.question = [request]

      answers = []
      @resolver.send(packet).answer.each do |rr|
        if rr.class == Net::DNS::RR::TXT then
          vals = {}
          elements = rr.txt.split(" ").reverse
          elements.each do |e|
            e =~ /([\w]*)=(.*)/
            vals[$1] = $2
          end
          answers << vals

        elsif rr.class == Net::DNS::RR::SRV then
          answers << {
            :priority => rr.priority,
            :weight => rr.weight,
            :port => rr.port,
            :host => rr.host
          }
        end
      end

      answers

    end
  end
end


res = Signpost::Resolver.new
res.get_key "sebastian.probst.eide.signpost.probsteide.com"
res.get_resource "sebastian.probst.eide", "sebastian.probst.eide.signpost.probsteide.com"
res.get_signpost "sebastian.probst.eide.signpost.probsteide.com"
res.get_resource "mb.anil.recoil.org", "macbook.signpost.probsteide.com"
res.get_key "macbook.signpost.probsteide.com"
res.get_key "macbook.signpost.probsteide.com"
res.get_key "sebastian.probst.eide.signpost.probsteide.com"
