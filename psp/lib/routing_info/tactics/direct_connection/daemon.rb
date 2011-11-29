#! /usr/bin/ruby

require 'rubygems' 
require 'daemons'

Daemons.run(File.dirname(__FILE__) + '/daemon_process.rb')
