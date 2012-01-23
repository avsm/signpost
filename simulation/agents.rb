module Agents
  class ResourceCPUConstrained < Exception
  end

  class Agent
    def initialize cpu = 2000
      # How much CPU is available
      @cpu = cpu
      @utilisation = 0

      @cacheable = true
    end

    def start_tick
      @tick_cpu = 0
    end

    def increase_cpu
      @tick_cpu += 1
      raise ResourceCPUConstrained.new "CPU busy" if @tick_cpu > @cpu
    end

    def cacheable?
      # Whether or not this item can be cached
      @cacheable 
    end

    def end_simulation
    end

    def end_tick
    end

    def utilisation
      @tick_cpu
    end

    def capacity
      @cpu
    end
  end

  class RootServer < Agent
    def initialize
      @domains = {}

      # Very powerful root servers
      super 100
    end

    def register domain
      @domains[domain.name] = domain
    end

    def resolve domain_name
      increase_cpu
      @domains[domain_name]
    end
  end

  class DomainRoot < Agent
    attr_accessor :popularity
    attr_reader :name

    def initialize root, signpost = false
      @name = (0...8).map{65.+(rand(25)).chr}.join
      @root = root

      # register with the root
      @root.register self

      @signpost = signpost

      # Somewhat powerful authoritative domain server
      super 20
    end

    def resolve domain_name
      increase_cpu
      # Send a response that can either be cached or not
      # Signpost repsonses are not cached
      RR.new @signpost
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
    attr_accessor :devices

    def initialize root_server
      # The cache size should probably vary?
      @cache_size = 1000
      @cache = {}

      @devices = []

      @root_server = root_server

      # If the domain root is busy, then
      # try again later. We need to keep track
      # of the times we couldn't do something
      @pending = []

      # Low end resolver
      super 20
    end

    def resolve domain_name
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

    def add_overhead overhead
      overhead.times {increase_cpu}
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
  end

  class Device < Agent
    attr_reader :resolver

    def initialize resolver, domains, p
      @resolver = resolver
      @domains = domains
      @p = p

      # How active is this device?
      # There is an X percentage chance
      # that the device will request a domain
      # in a given timestep
      @domain_request_prob = Distribution.powerlaw(p.min_prob_request_domain,
                                                   p.max_prob_request_domain,
                                                   p.request_domain_bias)

      # Notice that the device now also has a CPU (being an "agent").
      # This doesn't really make sense, but we can safely ignore it :)
      
      # Set of pending domain requests that couldn't be completed in
      # a given timestamp
      @pending = []

      @signpost_device = false
    end

    def add_signpost_sync_overhead
      # When another signpost makes a request, there is some sync
      # overhead.
      @resolver.add_overhead (@p.cost_of_signpost_request * 
                              @p.signpost_sync_overhead / 100) unless @cloud

    rescue ResourceCPUConstrained
      
    end

    # For makign a device into a signpost device
    def make_signpost others, cloud = true
      @signpost_device = true
      @cloud = cloud
      @other_devices_in_signpost_domain ||= []
      @other_devices_in_signpost_domain += others
      others.each do |other|
        other.add_other_signpost_domain_device self
      end
    end

    def add_other_signpost_domain_device device
      @other_devices_in_signpost_domain << device
    end

    def tick timestep
      # If we are a signpost device, then we have a
      # base cost of being noisy because of iodine
      @resolver.add_overhead @p.iodine_overhead if @signpost_device

    rescue ResourceCPUConstrained
    else

      normal_dns
      signpost_requests if @signpost
    end

    def add_friends friends
      @friends = friends
      @other_devices_in_signpost_domain.each do |o|
        o.also_know_friends friends
      end
    end

    def also_know_friends friends
      @friends = friends
    end

    # When another signposts accesses us, then there is some
    # sync amonst the signposts within this domain to setup tunnels
    def remote_access
      # For ourselves
      add_signpost_request_overhead
      @other_devices_in_signpost_domain.each do |c|
        c.add_signpost_request_overhead
      end
    end

  private
    def signpost_requests
      @friends.each do |friend|
        big_dice = Distribution.random(0, 99)
        if big_dice < friend[:prob_access] then
          # Access the friend, which causes
          # communication between those signposts.
          friend[:friend].remote_access
          # Looking up the friend also requires a DNS lookup
          @resolver.resolve friend[:domain]
          add_signpost_request_overhead
        end
      end

    rescue ResourceCPUConstrained
      # The resolver is busy, try again later
      @pending << domain

    end

    def normal_dns
      # Signpost devices that are in the cloud do not make DNS requests that
      # we care about.
      return if @signpost_device and @cloud

      domain = ""
      # Should we request a domain?
      big_dice = Distribution.random(0, 99)
      if big_dice < @domain_request_prob then
        domain = @domains.domain_to_request
        @resolver.resolve domain
        add_signpost_request_overhead
      end

      # If we have any pending requests, make sure to get them resolved
      resolved = []
      todo = []
      @pending.each {|t| todo << t}
      todo.each do |domain_name|
        domain = domain_name
        @resolver.resolve domain
        resolved << domain
        add_signpost_request_overhead
      end
      @pending.delete(resolved)

    rescue ResourceCPUConstrained
      # The resolver is busy, try again later
      @pending << domain

    end

    def add_signpost_request_overhead
      return unless @sinpost_device
      # When the client makes a request, since it is 
      # When a signpost client makes a request, there is
      # quite a bit of extra overhead, because it tunnels over iodine
      @resolver.add_overhead p.cost_of_signpost_request

      # Also add sync overhead for other signpsots.
      @other_devices_in_signpost_domain.each do |d|
        d.add_signpost_sync_overhead
      end
    end
  end

end
