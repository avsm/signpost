require 'rubygems'

# Module to generate different kinds of distributions
require './distributions'
# Load the definitions of the different agents we have
require './agents'
# Load the simulation constructors
require './simulation'

# This is a step based simulation.
# We move forward in discrete timesteps.
# Each user might or might not request to 
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
#   the percentage of the users who are signpost users.
# - N root servers
# - Ø resolvers
# - P users spread across the resolvers

########################################################################
#                      Simulation configuration                        #
########################################################################

class Params
  def initialize
    @params = {
      # How many timesteps we should simulate
      :timesteps => 2000,

      # Number of root servers : 1
      # Number of non-signpost enabled domains
      :min_domains => 1_000,
      :max_domains => 20_000,
      :min_domain_popularity => 1,
      :max_domain_popularity => 100,
      :domain_powerlaw_bias => 10,
      
      # Number of resolvers
      # The number of users per resolver follows
      # a powerlaw distribution. We have some big
      # prominent resolvers, and some more private ones.
      :min_resolvers => 50,
      :max_resolvers => 60,
      :min_users_per_resolver => 1,
      :max_users_per_resolver => 100,
      :users_per_resolver_powerlaw_bias => 20,

      # Chance that a given user requests a random
      # domain in a given timestep
      :min_prob_request_domain => 0,
      :max_prob_request_domain => 50,
      :request_domain_bias => 4
    }
  end

  def method_missing param
    return @params[param] if @params[param] 
    throw "Missing parameter"
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

# Setup a root domain server
puts "Setting up root"
root = Agents::RootServer.new

# We have X regular domains.
# The domains differ in popularity
# (for now following a power law distribution
puts "Setting up domains"
domains = Simulation::SetupDomains.new p, root

# Setup the resolvers for this simulation
puts "Setting up resolvers and users"
resolver_container = Simulation::SetupResolvers.new p, domains, root

# We keep track of the current timestep.
current_timestep = 0

#######################
# Run simulation
#######################

resolvers = resolver_container.resolvers
users = resolver_container.users

puts "Starting simulation"

while current_timestep < p.timesteps
  print "."
  print "\n" if current_timestep % 100 == 0

  #---------------------------------------------
  # Tell each agent that the tick is about to start
  root.start_tick
  domains.start_tick
  resolvers.each {|r| r.start_tick}
  users.each {|u| u.start_tick}
  #---------------------------------------------

  # Tick each resolver
  resolvers.each {|resolver| resolver.tick current_timestep}

  # Tick each user
  users.each {|user| user.tick current_timestep}

  #---------------------------------------------
  # Tell each agent that the tick is about to end
  root.end_tick
  domains.end_tick
  resolvers.each {|r| r.end_tick}
  users.each {|u| u.end_tick}
  #---------------------------------------------
  
  # Move to the next timestep
  current_timestep += 1
end

#---------------------------------------------
# Tell each agent that the tick is about to start
root.end_simulation
domains.end_simulation
resolvers.each {|r| r.end_simulation}
users.each {|u| u.end_simulation}
resolver_container.end_simulation
#---------------------------------------------

# Print out utilisation graph
root_utilisation = root.utilisation
ns_utilisation = domains.utilisation
resolver_utilisation = resolver_container.utilisation

puts "Root utilisation;NS Utilisation;Resolver utilisation"
root_utilisation.each_index do |n|
  puts "#{root_utilisation[n]};#{ns_utilisation[n]};#{resolver_utilisation[n]}"
end
