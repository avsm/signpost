#!/usr/bin/env ruby

require 'yaml'
require 'pp'

# Channels are the different tunnel types we are testing
# They are all scheduled to run their set of tests once per hour.
# The timings are given in minutes past the hour.

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
    channels = []
    tunnels.each do |tunnel|
      channels << {
        :name => tunnel["name"],
        :ip => tunnel["ip"],
        :port => tunnel["port"],
        :time => tunnel["time"],
        :interface => tunnel["interface"]
      }
    end
    channels.sort do |a,b|
      a[:time] <=> b[:time]
    end
  end

  def self.seconds_to_sleep c, next_hour = false
    t = Time.now
    time_now = Time.utc(t.year, t.month, t.day, t.hour, t.min, t.sec).to_i
    execute_at = Time.utc(t.year, t.month, t.day, 
                          t.hour + (next_hour ? 1 : 0), c[:time]).to_i
    execute_at - time_now
  end

  def self.next_test channels
    current_time = Time.now.min
    # Find the test that is the next to run
    ok_channels = channels.select do |c| 
      (c[:time] > current_time) or 
      (current_time >= channels.last[:time])
    end
    next_test = ok_channels.first
    # Wait for the right time for the test to start
    wait = if current_time >= channels.last[:time] then
      seconds_to_sleep next_test, true
    else
      seconds_to_sleep next_test
    end
    # Wait until the next test is supposed to be run
    puts "[#{next_test[:name]}] will execute in #{wait} seconds"
    sleep(wait)
    next_test
  end
end

channels = Test.get_channels

while true
  test = Test.next_test channels
  # Run the different tests
  # Insert execution of scripts that are needed here...
end
