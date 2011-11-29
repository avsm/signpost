require "rubygems"
require 'bud'
require 'pp'

gem "json"
begin
  require "json/ext"
rescue LoadError
  $stderr.puts "C version of json (fjson) could not be loaded, using pure ruby one"
  require "json/pure"
end

require 'json/add/core'
require 'thread'

$:.unshift File.dirname(__FILE__)

require 'routing_info/tactic_protocol'
require 'routing_info/tactic'
require 'routing_info/info_collector'

module RoutingInfo
  
end
