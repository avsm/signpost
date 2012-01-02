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

require 'tactic_solver/tactic_protocol'
require 'tactic_solver/tactic_helpers'
require 'tactic_solver/tactic_pool'
require 'tactic_solver/comms_agent'
require 'tactic_solver/tactic'
require 'tactic_solver/question'
require 'tactic_solver/solver'

module TacticSolver
  
end
