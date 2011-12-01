require 'rubygems'
gem 'minitest'
require 'minitest/unit'
require 'minitest/autorun'

# Include the libraries themselves that we are testing
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'tactic_solver'
