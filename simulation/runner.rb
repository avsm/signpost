require 'rubygems'
require 'pp'

# Module to generate different kinds of distributions
require './distributions'
# Load the definitions of the different agents we have
require './agents'
# Load the simulation constructors
require './simulation'

# This is a step based simulation.
# We move forward in discrete timesteps.
# Each device might or might not request to 
# get a domain name resolved.
# A resolution for now only takes a single
# timestep, and in that timestep affects
# all the entities it touches in terms of 
# CPU. It can affect a resolvers cache for
# an extended number of timesteps.

# All the agents taking part in this simulation.
# We have:
# - 1 root server
# - M number of DomainRoots, X for regular domains, and Y for
#   the percentage of the devices who are signpost devices.
# - N root servers
# - Ø resolvers
# - P devices spread across the resolvers

########################################################################
#                      Simulation configuration                        #
########################################################################

class Params
  def initialize
    @params = {
      # How many timesteps we should simulate
      :timesteps => 100,

      # Number of root servers : 1
      # Number of non-signpost enabled domains
      :min_domains => 10_000,
      :max_domains => 10_000,
      :min_domain_popularity => 1,
      :max_domain_popularity => 100,
      :domain_powerlaw_bias => 15,
      
      # Number of resolvers
      # The number of devices per resolver follows
      # a powerlaw distribution. We have some big
      # prominent resolvers, and some more private ones.
      :min_resolvers => 40,
      :max_resolvers => 40,
      :min_devices_per_resolver => 5,
      :max_devices_per_resolver => 1_000,
      :devices_per_resolver_powerlaw_bias => 20,

      # Chance that a given device requests a random
      # domain in a given timestep
      :min_prob_request_domain => 0,
      :max_prob_request_domain => 80,
      :request_domain_bias => 2,

      # Social networking kind of parameters
      :min_number_of_friends => 1,
      :max_number_of_friends => 100,
      :friend_count_powerlaw_bias => 20,
      # This is to order the friends by likelihood of contact
      :min_prob_access_friend => 0,
      :max_prob_access_friend => 100,
      :access_friend_powerlaw_bias => 10,

      ######
      ## TODO: Get sensible numbers for cost of iodine etc.
      ######
      
      # Percentage of devices that are signpost enabled
      :percentage_signposts => 0,
      # Percentage of signposts located at the edge
      :signposts_at_edge => 20,
      # The number of signposts, or devices each user has
      :min_num_signposts => 2,
      :max_num_signposts => 20,
      :num_signposts_bias => 4,
      # How much sync traffic there is between signposts
      # as a result of a signpost communication,
      # in percentage
      :signpost_sync_overhead => 100,
      # Cost of a signpost request, in multiples 
      # of a normal request
      :cost_of_signpost_request => 40,
      # Iodine tunnel overhead per simulation timestep
      :iodine_overhead => 10
    }
  end

  def update what, to
    @params[what] = to
  end

  def method_missing param
    return @params[param] if @params[param] 
    puts "Couldn't find '#{param}'"
    raise "Missing parameter"
  end
end


########################################################################
#                       Simulation code below                          #
########################################################################

#######################
# Setup initial state
#######################

# Get a params instance that we can use in the simulation
p = Params.new


puts "Starting simulation"

file_name = "simulation-#{Time.now.year}-#{Time.now.month}-#{Time.now.day}-#{Time.now.hour}-#{Time.now.sec}"

puts "Writing results to results.dat"
File.open("r.script", "w") do |r|
File.open("#{file_name}.dat", "w") do |f|
  # Print work commands for r script
  r.puts "r <- read.table('#{file_name}.dat', header=T)"
  r.puts "png('#{file_name}.png');"

  labels = []
  levels = []

  # Print header for results table
  f.puts "percentage\troot\tns\tresolver"

  [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100].each do |percentage|
    p.update :percentage_signposts, percentage
    
    # Setup a root domain server
    puts "Setting up root server for simulation run"
    root = Agents::RootServer.new

    # We have X regular domains.
    # The domains differ in popularity
    # (for now following a power law distribution
    puts "Setting up domains for simulation run"
    domains = Simulation::SetupDomains.new p, root

    # Setup the resolvers for this simulation
    puts "Setting up resolvers and devices for simulation run"
    resolver_container = Simulation::SetupResolvers.new p, domains, root

    # We keep track of the current timestep.
    current_timestep = 0

    puts "Starting simulation run at #{percentage}% signposts"

    #######################
    # Run simulation
    #######################

    resolvers = resolver_container.resolvers
    devices = resolver_container.devices

    while current_timestep < p.timesteps
      print "\n" if current_timestep % 100 == 0
      print "."

      #---------------------------------------------
      # Tell each agent that the tick is about to start
      root.start_tick
      domains.start_tick
      resolvers.each {|r| r.start_tick}
      devices.each {|u| u.start_tick}
      #---------------------------------------------

      # Tick each resolver
      resolvers.each {|resolver| resolver.tick current_timestep}

      # Tick each device
      devices.each {|device| device.tick current_timestep}

      # Write out data for logs
      percentage = p.percentage_signposts
      root_util = root.utilisation.to_f / root.capacity
      ns_util = domains.utilisation
      resolver_util = resolver_container.utilisation
      f.puts "#{percentage}\t#{root_util}\t#{ns_util}\t#{resolver_util}"

      #---------------------------------------------
      # Tell each agent that the tick is about to end
      root.end_tick
      domains.end_tick
      resolvers.each {|r| r.end_tick}
      devices.each {|u| u.end_tick}
      #---------------------------------------------
      
      # Move to the next timestep
      current_timestep += 1

    end # end while look

    labels << "root at #{percentage}" <<
              "ns at #{percentage}" <<
              "resolver at #{percentage}"
    levels << percentage
    r.puts "root_#{percentage} <- r$root[r$percentage==\"#{percentage}\"]"
    r.puts "ns_#{percentage} <- r$ns[r$percentage==\"#{percentage}\"]"
    r.puts "resolver_#{percentage} <- r$resolver[r$percentage==\"#{percentage}\"]"
    
    #---------------------------------------------
    # Tell each agent that the tick is about to start
    root.end_simulation
    domains.end_simulation
    resolvers.each {|r| r.end_simulation}
    devices.each {|u| u.end_simulation}
    resolver_container.end_simulation
    #---------------------------------------------

  end # end each-percentage

  r.puts "all_data <- c(#{
      (levels.map {|l| "root_#{l}, ns_#{l}, resolver_#{l}"}).join(", ")
  })"
  num_levels = 3 * levels.size
  steps = p.timesteps
  datapoints = num_levels * steps
  r.puts "levels <- gl(#{num_levels}, #{steps}, #{datapoints}, labels=c(#{
    (labels.map {|l| "\"#{l}\""}).join(", ")
  }))"
  r.puts "plot(levels, all_data)"
  r.puts "dev.off()"

end # end results.dat file
end # end r-script file

#---------------------------------------------
puts "Generating graphs"
`r -f r.script`
puts "Outputting graph to #{file_name}.png"

puts "Experiment done"

