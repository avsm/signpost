#! /usr/bin/ruby
require 'rubygems'
gem 'json'
require 'json/ext'

r = {:hello => true}
puts r.to_json