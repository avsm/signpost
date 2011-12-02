#! /usr/bin/ruby

require 'rubygems'
require 'pp'
gem "json"
require 'json/ext'
require 'socket'

$stdout.sync = true
$stderr.sync = true

@values = {}

def provide_truth what, value
  new_truth = {
      :provide_truths => [{
          :what => what,
          :cacheable => true,
          :value => value
      }]
  }
  $stdout.puts new_truth.to_json
end

def eval_tcp_out 
  # new_truth = {
  #     :provide_truths => [{
  #         :what => what,
  #         :cacheable => false,
  #         :value => value
  #     }]
  # }
  # $stderr.puts "Got truth: #{what} -> #{value}"
  # $stdout.puts new_truth.to_json
  exit 0
end

def eval_tcp_in 
  # new_truth = {
  #     :provide_truths => [{
  #         :what => what,
  #         :cacheable => false,
  #         :value => value
  #     }]
  # }
  begin
    s = TCPServer.open @values["port"]
    s.close
    # Could open a listening post
    provide_truth @values["what"], true

  rescue Errno::EACCES
    # Failed at opening port in
    provide_truth @values["what"], false
    
  end
end

should_run = true
while should_run
  value = $stdin.gets
  
  begin
    data = JSON.parse(value)
    
    if data['terminate'] then
      should_run = false
      
    elsif data['truths'] then
      received_truths = data['truths']
      received_truths.each do |truth|
        what = truth["what"]
        value = truth["value"]
        @values[what] = value
        
        @values[:tcp_in] = true if value == "tcp_in"
        @values[:tcp_out] = true if value == "tcp_out"

      end
    end

    if (@values[:tcp_in] and @values["port"]) then
      eval_tcp_in
      should_run = false
    end

    if (@values[:tcp_out] and @values["port"] and @values["domain"]) then
      eval_tcp_out
      should_run = false
    end
    
  rescue JSON::ParserError
    $stderr.puts "Couldn't parse the input"
    
  end
end
