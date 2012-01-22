module Simulation
  class SetupDomains
    attr_reader :utilisation

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

    def end_simulation
      puts "Had #{@domain_roots.size} domains"

      @utilisation = Array.new(@domain_roots.first.utilisation.size)
      @domain_roots.each do |d|
        d.utilisation.each_index do |n|
          @utilisation[n] ||= 0
          @utilisation[n] += d.utilisation[n]
        end
      end
      num_domains = @domain_roots.size
      @utilisation.map {|u| u / num_domains}
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
    attr_reader :resolvers, :users, :utilisation

    def initialize p, domains, root_server
      # We have Ø resolvers
      @resolvers = []
      # We have P users in total
      @users = []

      (Distribution.random(p.min_resolvers, p.max_resolvers)).times do |n|
        resolver = Agents::Resolver.new root_server
        # Now generate users for the resolver
        num_users = Distribution.powerlaw(p.min_users_per_resolver,
                                          p.max_users_per_resolver,
                                          p.users_per_resolver_powerlaw_bias)
        num_users.times do |n|
          user = Agents::User.new resolver, domains, p
          resolver.users << user
          @users << user
        end

        @resolvers << resolver
      end
    end

    def end_simulation
      @utilisation = Array.new(@resolvers.first.utilisation.size)
      @resolvers.each do |r|
        r.utilisation.each_index do |n|
          @utilisation[n] ||= 0
          @utilisation[n] += r.utilisation[n]
        end
      end
      num_resolvers = @resolvers.size
      @utilisation.map {|u| u / num_resolvers}
    end
  end
end
