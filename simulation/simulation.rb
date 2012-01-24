module Simulation
  class SetupDomains
    def initialize p, root_server
      @domain_roots = []
      @domains_upper_probability_bound = 0
      @domain_prob = {}
      # We generate X regular domains
      (Distribution.random(p.min_domains, p.max_domains)).times do |n|
        domain = Agents::DomainRoot.new root_server
        popularity = Distribution.powerlaw(p.min_domain_popularity,
                                           p.max_domain_popularity,
                                           p.domain_powerlaw_bias)
        # Make it so that we can select a random domain with a given
        # popularity.
        popularity.times do |n|
          @domain_prob[@domains_upper_probability_bound + n] = domain
        end
        @domains_upper_probability_bound += popularity

        domain.popularity = popularity
        @domain_roots << domain
      end
    end

    def domain_to_request
      # Get a number in the range of domains to request
      domain_num = Distribution.random(0, @domains_upper_probability_bound)
      @domain_prob[domain_num].name
    end

    def utilisation
      util = 0
      max = 0
      @domain_roots.each {|r| 
        util += r.utilisation
        max += r.capacity
      }
      util.to_f / max
    end

    def end_simulation
      puts "Had #{@domain_roots.size} domains"
    end

    def start_tick
      @domain_roots.each do |ns|
        ns.start_tick
      end
    end

    def end_tick
      @domain_roots.each do |ns|
        ns.end_tick
      end
    end
  end

  class SetupResolvers
    attr_reader :resolvers, :devices

    def initialize p, domains, root_server
      # We have Ø resolvers
      @resolvers = []
      # We have P devices in total
      @devices = []

      (Distribution.random(p.min_resolvers, p.max_resolvers)).times do |n|
        resolver = Agents::Resolver.new root_server
        # Now generate devices for the resolver
        num_devices = Distribution.powerlaw(p.min_devices_per_resolver,
                                          p.max_devices_per_resolver,
                                          p.devices_per_resolver_powerlaw_bias)
        num_devices.times do |n|
          device = Agents::Device.new resolver, domains, p
          resolver.devices << device
          @devices << device
        end

        @resolvers << resolver
      end

      puts "Created #{@resolvers.size} resolvers"
      puts "Created #{@devices.size} clients"

      ###################
      # MAKE SOME DEVICES INTO SIGNPOSTS
      ###################
      
      # Now we want to make X percent of the devices into signpost
      # devices.
      num_devices = @devices.size
      percentage = p.percentage_signposts
      num_signpost_devices = num_devices * percentage / 100

      puts "Making #{num_signpost_devices} into signposts"

      # Choose a set of devices, that can be made into signposts
      signposts = select_devices @devices, num_signpost_devices
      previous = []
      to_add = 0
      groups = []
      signposts.each do |signpost|
        # Find how many we should add to a user
        if to_add == 0 then
          previous = []
          groups << signpost
          to_add = Distribution.powerlaw(p.min_num_signposts,
                                         p.max_num_signposts,
                                         p.num_signposts_bias)
        end
        to_add -= 1

        # On average P percent of a users signposts are in the cloud
        # Should this one be?
        cloud = false
        cloud = true if (rand(100).to_i) > p.signposts_at_edge
        signpost.make_signpost previous, cloud
        previous << signpost
        if cloud then
          # We create another device for the same resolver.
          # Otherwise we have fewer devices per resolver when
          # more signposts migrate to the cloud, and that doesn't
          # make sense
          resolver = signpost.resolver
          device = Agents::Device.new resolver, domains, p
          @devices << device
        end
      end

      # Assign friends to all the signpsost.
      groups.each do |group_leader|
        sp_domain = Agents::DomainRoot.new root_server, true

        # So let's find a set of friends from the other
        # signpost domains ("groups")
        num_friends = Distribution.powerlaw(p.min_number_of_friends,
                                            p.max_number_of_friends,
                                            p.friend_count_powerlaw_bias)
        friends = select_devices groups - [group_leader], num_friends
        group_leader.add_friends friends.map do |friend|
          {
            :friend => friend, 
            :prob_access => Distribution.powerlaw(p.min_prob_access_friend,
                                                  p.max_prob_access_friend,
                                                  p.access_friend_powerlaw_bias),
            :domain => sp_domain.name
          }
        end

      end
    end

    # Returns random num devices
    def select_devices selection, num
      devices = []
      return selection if num >= selection.size
      while num > 0 do
        device = selection[rand(selection.size).to_i]
        unless devices.include?(device) then
          devices << device
          num -= 1
        end
      end
      devices
    end

    def utilisation
      util = 0
      max = 0
      @resolvers.each {|r| 
        util += r.utilisation
        max += r.capacity
      }
      util.to_f / max
    end

    def end_simulation
    end
  end
end
