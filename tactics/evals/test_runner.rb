#!/usr/bin/env ruby

require 'yaml'
require 'pp'

# Channels are the different tunnel types we are testing
# They are all scheduled to run their set of tests twice and hour.
# The timings are given in minutes past the hour and past the half hour.
#
# There is currently 4 minutes to spread around for tests that need it.

# Flows 
# - TCP
# - UDP low
# - UDP high
# - HTTP

module Test
  def self.get_channels
    config_file = "config.yml"
    raise "Missing test configuration file" unless File.exist? config_file
    config = YAML::load(File.open(config_file))
    tunnels = config["tunnels"]
    first_half_channels = []
    tunnels.each do |tunnel|
      first_half_channels << {
        :name => tunnel["name"],
        :ip => tunnel["ip"],
        :port => tunnel["port"],
        :time => tunnel["time"],
        :interface => tunnel["interface"]
      }
    end
    channels = first_half_channels + first_half_channels.map do |c|
      val = {}.merge(c)
      val[:time] = c[:time] + 30
      val
    end
  end

  def self.time
    Time.now.sec
  end

  def self.next_test channels
    current_time = time
    # Find the test that is the next to run
    ok_channels = channels.select do |c| 
      (c[:time] > current_time) or 
      (current_time >= channels.last[:time])
    end
    next_test = ok_channels.first
    # Wait for the right time for the test to start
    wait = if current_time >= channels.last[:time] then
      # We are at the end of an hour
      60 - current_time + next_test[:time]
    else
      next_test[:time] - current_time
    end
    sleep(wait)
    next_test
  end
end

channels = Test.get_channels

while true
  test = Test.next_test channels
  # Run the different tests
  puts "Running #{test[:name]} (#{test[:time]}). Current time: #{Test.time}"
  # Insert execution of scripts that are needed here...
end
