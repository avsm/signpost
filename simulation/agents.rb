module Agents
  class ResourceCPUConstrained < Exception
  end

  class Agent
    attr_reader :utilisation

    def initialize cpu = 2000
      # How much CPU is available
      @cpu = cpu
      @utilisation = []

      @cacheable = true
    end

    def start_tick
      @tick_cpu = 0
    end

    def increase_cpu
      @tick_cpu += 1
      raise ResourceCPUConstrained.new "CPU busy" if @tick_cpu > @cpu
    end

    def end_tick
      @utilisation << @tick_cpu.to_f / @cpu if @cpu
      # Do whatever processing needed in the children
    end

    def cacheable?
      # Whether or not this item can be cached
      @cacheable 
    end

    def end_simulation
    end
  end

  class RootServer < Agent
    def initialize
      @domains = {}

      # Very powerful root servers
      super 1000
    end

    def register domain
      @domains[domain.name] = domain
    end

    def resolve domain_name
      @accesses = @accesses + 1
      increase_cpu
      @domains[domain_name]
    end

    def start_tick
      super
      @accesses = 0
    end

    def end_tick
      # puts "Root server accessed #{@accesses} times"
      super
    end
  end

  class DomainRoot < Agent
    attr_accessor :popularity
    attr_reader :name

    def initialize root
      @name = (0...8).map{65.+(rand(25)).chr}.join
      @root = root

      # register with the root
      @root.register self

      # Somewhat powerful authoritative domain server
      super 40
    end

    def resolve domain_name
      @accesses = @accesses + 1
      increase_cpu
      RR.new
    end

    def start_tick
      super
      @accesses = 0
    end

    def end_tick
      # puts "Domain NS server for #{name} was accessed #{@accesses} times"
      super
    end
  end

  # This is the result returned
  class RR
    def initialize cacheable = true
      @cacheable = cacheable
    end

    def cacheable?
      @cacheable
    end
  end

  class Resolver < Agent
    attr_accessor :users

    def initialize root_server
      # The cache size should probably vary?
      @cache_size = 1000
      @cache = {}

      @users = []

      @root_server = root_server

      # If the domain root is busy, then
      # try again later. We need to keep track
      # of the times we couldn't do something
      @pending = []

      # Low end resolver
      super 100
    end

    def resolve domain_name
      @accesses = @accesses + 1
      increase_cpu

      begin
        # Check if the domain is in the cache
        if @cache[domain_name] then
          # Update count
          @cache[domain_name][:count] += 1

          # What sort of record do we have?
          
          # We have the result cached, return immediately
          return if @cache[domain_name][:rr]

          if @cache[domain_name][:ns] then
            # We have the name server, request the domain
            ns = @cache[domain_name][:ns]
            rr = ns.resolve domain_name
            @cache[domain_name][:rr] = rr if rr.cacheable?
            return
          end

        else
          # We have no entry for this domain
          ns = @root_server.resolve domain_name
          @cache[domain_name] = {:count => 1}
          @cache[domain_name][:ns] = ns if ns.cacheable?
          resolve domain_name

        end

      rescue ResourceCPUConstrained
        # One of the levels was busy, try again next timestep
        @pending << domain_name

      end

    end

    def tick timestep
      resolved = []
      todo = []
      @pending.each {|t| todo << t}
      todo.each do |domain_name|
        resolve domain_name
        resolved << domain_name
      end

    rescue ResourceCPUConstrained
      # Damn, not much we can do :| 
      # I guess we can only wait and try resolving again later
      
    ensure
      @pending.delete(resolved)

    end

    def end_simulation
      # puts "Resolver has #{@pending.size} unresolved requests"
      @cache.each_pair do |domain, data|
        # puts "Domain #{domain} requested #{data[:count]} times"
      end
    end

    def start_tick
      super
      @accesses = 0
    end

    def end_tick
      super
    end
  end

  class User < Agent
    attr_reader :name

    def initialize resolver, domains, p
      @resolver = resolver
      @domains = domains
      @friends = []

      name = (0...8).map{65.+(rand(25)).chr}.join
      @name = name.downcase.capitalize

      # How active is this user?
      # There is an X percentage chance
      # that the user will request a domain
      # in a given timestep
      @domain_request_prob = Distribution.powerlaw(p.min_prob_request_domain,
                                                   p.max_prob_request_domain,
                                                   p.request_domain_bias)

      # Notice that the user now also has a CPU (being an "agent").
      # This doesn't really make sense, but we can safely ignore it :)
      
      # Set of pending domain requests that couldn't be completed in
      # a given timestamp
      @pending = []
    end

    def tick timestep
      domain = ""

      # Should we request a domain?
      big_die_throw = Distribution.random(0, 99)
      if big_die_throw < @domain_request_prob then
        domain = @domains.domain_to_request
        @resolver.resolve domain
      end

      # If we have any pending requests, make sure to get them resolved
      resolved = []
      todo = []
      @pending.each {|t| todo << t}
      todo.each do |domain_name|
        domain = domain_name
        @resolver.resolve domain
        resolved << domain
      end
      @pending.delete(resolved)

    rescue ResourceCPUConstrained
      # The resolver is busy, try again later
      @pending << domain

    end

    def end_simulation
      # puts "User has #{@pending.size} unresolved requests"
      # puts "Had domain request probability of #{@domain_request_prob}%"
    end
  end
end
