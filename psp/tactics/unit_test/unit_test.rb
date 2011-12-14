#! /usr/bin/ruby

require 'rubygems'
require 'pp'
gem "json"
require 'json/ext'

$stdout.sync = true
$stderr.sync = true

# Express a need
need1 = {:what => "unit_test_need"}
need2 = {:what => "unit_test_need", :domain => "domainA"}
need3 = {:what => "unit_test_need", :destination => "domainB:30"}
need4 = {:what => "unit_test_need", :domain => "domainC", :port => 40}
  
needs = {:need_truths => [need1, need2, need3, need4]}
$stdout.puts needs.to_json

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
