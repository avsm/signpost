module TacticSolver
  class Solver
    include Bud
    include TacticProtocol

    state do
      # These are the truths that we know
      # We know WHAT sort of truth they are
      # We know WHO the truth was made for
      # and we know the TRUTH itself
      table :truths, [:what, :provider, :user_info, :signpost] => [:truth, :ttl_state]

      # These are the truths that are subscribed to
      # We know WHAT truth is needed
      # and WHO needs the truth
      table :truth_subscribers, [:what, :who] => [:user_info, :who_name]

      # Truths that can now be satisfied
      # We know WHO needs WHAT and for WHAT user,
      # and the TRUTH needed
      scratch :satisfiable_truth_needs, [:who, :what, :user_info] => [:truth]

      # For adapting truths to serve to anyone
      scratch :adapted_provided_truths, [:what, :original_what, :provider, :user_info, :signpost] => [:truth]

      # Temp for adding ttl state to new truths. Ideally this would only be
      # a in block temp collection, but the temp collections do not support
      # schemas.
      scratch :storable_truths, [:what, :provider, :user_info, :signpost] => [:truth, :ttl_state]

      # Garbage collection timer
      periodic :garbage_collection_timer, 10

      # truth to be redistributed
      scratch :redistributable_truths, [:what, :provider, :user_info, :signpost] => [:truth, :ttl]

      # FIXME: Find better way to deliver this truth, than through a channel...
      # :(
      channel :provide_truth_from_external
    end

    # Remove truths that are no longer valid
    bloom :garbage_collection do
      truths <- (garbage_collection_timer*truths).pairs do |g,t|
        t unless ttl_is_valid? t
      end
    end

    # Unsubscribe tactics that terminate
    bloom :remove_leavers do
      remove_subscriptions_scratch <= remove_subscriptions.payloads
      truth_subscribers <- (truth_subscribers*remove_subscriptions_scratch).
          lefts(:who => :who)
    end

    # Exchange truths with tactics
    bloom :tactic_comms do
      need_truth_scratch <= need_truth.payloads
      observe_truth_scratch <= observe_truth.payloads

      # A tactic subscribes to a truth so it receives new truths
      # as they come in.
      truth_subscribers <+- need_truth_scratch
      # A tactic can also just become an observer.
      # This will not cause a new truth to be generated
      truth_subscribers <+- observe_truth_scratch

      # Let's see if we can satisfy the truths directly from our truth cache
      satisfiable_truth_needs <= (truths*need_truth_scratch).
          pairs(:what => :what) {|t, nt| 
        if ((t.user_info == "GLOBAL" or t.user_info == nt.user_info) and
              ttl_is_valid? t) then
          # Create a truth without the TTL state
          truth = [t.what, t.provider, t.user_info, t.signpost, t.truth]
          # Pass the truth back to the user
          [nt.who, t.what, nt.user_info, truth]
        end
      }
      needed_truth <~ satisfiable_truth_needs {|stn| [stn.who, stn.truth]}

      # Find needs that we cannot satisfy, and register them
      temp :dev_null_1 <= need_truth_scratch do |nt|
        unless satisfiable_truth_needs.exists? {|s|
          s.what == nt.what and (s.user_info == nt.user_info or s.user_info == "GLOBAL")
        } then
          @_thread_pool.explore_truth_space_for nt.what, nt.user_info
        end
      end
      
      # Distribute truths to the network
      redistributable_truths <= provide_truth.payloads
      temp :dev_null_2 <= redistributable_truths do |t|
        @communication_center.distribute_truths [[t.what, t.provider, t.user_info, t.signpost, t.truth, t.ttl]]
      end

      provide_truth_scratch <= provide_truth_from_external.payloads
      provide_truth_scratch <= provide_truth.payloads
      # We received a new truth. Now we need to create
      # a ttl_state session for this truth so we can convert
      # it into a truth ready for the truth table.
      storable_truths <= provide_truth_scratch do |t|
        ttl = t.ttl
        ttl_state = create_ttl_state ttl
        [t.what, t.provider, t.user_info, t.signpost, t.truth, ttl_state] if ttl > 0
      end
      truths <+- storable_truths

      needed_truth <~ (provide_truth_scratch*truth_subscribers).
          pairs(:what => :what) do |p,t|
        if (p.user_info == "GLOBAL" or p.user_info == t.user_info) then
          [t.who, [p.what, p.provider, p.user_info, p.signpost, p.truth]]
        end
      end

      # If a daemon is subscribing to resource from ANY domain
      # then we need an alternative approach.
      # Also realise that the daemon gets the truth REGARDLESS
      # of the user info!
      adapted_provided_truths <= provide_truth_scratch do |t|
        # Get the resource part of the what
        t.what =~ /([[:graph:]]*)@.*/
        alternative_what = "#{$1}@ANY"
        [alternative_what, t.what, t.provider, t.user_info, t.signpost, t.truth]
      end
      needed_truth <~ (adapted_provided_truths*truth_subscribers).
          pairs(:what => :what) do |p,t|
        [t.who, [p.original_what, p.provider, p.user_info, p.signpost, p.truth]]
      end
    end

    bootstrap do
      truths <= [
        ["web_auth_url@node_name", 
         "global_truth",
         "GLOBAL", 
         @name,
         "http://localhost:8080/requests",
         create_ttl_state(1_000_000)]
      ]
    end

    def initialize node_name = "default", options = {}
      @name = node_name

      super options
      self.run_bg
      
      # Pool for tactics
      @_thread_pool = TacticPool.new @name, ip_port

      # For communication with other signposts
      @communication_center = CommunicationCentre.new self, "sebastian.kle.io"
    end

    def add_external_truth truth
      sync_do {provide_truth_from_external <~ [[ip_port, truth]]}
    end

    def resolve what, user_info
      options = {:what => what, :solver => ip_port, :user_info => user_info}
      question = Question.new options do |truths|
        puts "QUESTION #{what}"
        truths.to_a.each do |truth|
          truth_name, who, user_info, answer = truth
          puts "ANSWER:"
          puts "\ttruth: #{truth_name}"
          puts "\tprovider: #{who}"
          puts "\tuser_info: #{user_info}"
          if answer.class == Array then
            puts "\tdata: [#{answer.join(", ")}]"
          else
            puts "\tdata: [#{answer}]"
          end
        end
      end
    end

    def tactics
      @_thread_pool.tactics
    end

    # This method is called by the communication agent to
    # find the truths that are ours that we hold.
    # It also readies them for export.
    def exportable_truths
      # We only export truths that are from this signpost
      exports = self.truths.to_a.select do |t|
        t[3] == @name
      end
      # Turns TTL from a timestamp, back into a regular TTL
      exports.map do |t|
        ttl_state = t.pop
        ttl = ttl_state[:expires] - Time.now.to_i
        t.push ttl
      end
    end

  private
    def ttl_is_valid? truth
      return false if truth.ttl_state == :non_cacheable
      ttl_state = truth.ttl_state
      ttl_state[:expires] > Time.now.to_i
    end

    def create_ttl_state ttl
      if ttl == 0 then
        :non_cacheable
      else
        {
          :ttl => ttl,
          :expires => Time.now.to_i + ttl
        }
      end
    end
  end
end
