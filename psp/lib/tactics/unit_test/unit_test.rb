#! /usr/bin/ruby

require 'rubygems'
require 'pp'
gem "json"
require 'json/ext'

$stdout.sync = true
$stderr.sync = true

should_run = true
while should_run
  value = $stdin.readline("\n")

  begin
    data = JSON.parse(value)

    if data['terminate'] then
      should_run = false

    elsif data['truths'] then
      received_truths = data['truths']
      received_truths.each do |truth|
        what = truth['what']
        value = truth['value']
        source = truth['source']

        new_truth = {
          :provide_truths => [{
            :what => what,
            :cacheable => false,
            :value => value
          }]
        }
        $stdout.puts new_truth.to_json
      end
    end

  rescue JSON::ParserError
    $stderr.puts "Couldn't parse the input"

  end
end
