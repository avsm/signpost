module TacticSolver
  class Solver
    include Bud
    include TacticProtocol

    attr_reader :tactics

    state do
      # These are the truths that we know
      # We know WHAT sort of truth they are
      # and we know the TRUTH itself
      table :truths, [:what, :provider] => [:truth, :user_info]

      # These are the truths that are subscribed to
      # We know WHAT truth is needed
      # and WHO needs the truth
      table :truth_subscribers, [:what, :who] => [:who_name, :user_info]

      # These are the services provided
      # We know WHAT services are provided
      # and WHO provices the service
      table :providers, [:what] => [:who]

      scratch :satisfiable_truth_needs, [:who, :what] => [:truth, :user_info]
    end

    # Unsubscribe tactics that terminate
    bloom :remove_leavers do
      remove_subscriptions_scratch <= remove_subscriptions.payloads
      truth_subscribers <- (truth_subscribers*remove_subscriptions_scratch).lefts(:who => :who)
    end

    # Exchange truths with tactics
    bloom :tactic_comms do
      need_truth_scratch <= need_truth.payloads

      # A tactic subscribes to a truth so it receives new truths
      # as they come in.
      truth_subscribers <+- need_truth_scratch

      # Let's see if we can satisfy the truths directly from our truth cache
      satisfiable_truth_needs <= (truths*need_truth_scratch).
          pairs(:what => :what) {|t, nt| 
        if (t.user_info == "GLOBAL" or t.user_info == nt.user_info) then
          [nt.who, t.what, t, nt.user_info]
        end
      }
      needed_truth <~ satisfiable_truth_needs {|stn| [stn.who, stn.truth]}

      # Find needs that we cannot satisfy, and register them
      temp :dev_null <= need_truth_scratch do |nt|
        unless satisfiable_truth_needs.exists? {|s|
          s.what == nt.what and (s.user_info == nt.user_info or s.user_info == "GLOBAL")
        } then
          explore_truth_space_for nt.what, nt.user_info
        end
      end

      provide_truth_scratch <= provide_truth.payloads
      truths <= provide_truth_scratch
      needed_truth <~ (provide_truth_scratch*truth_subscribers).pairs(:what => :what) do |p,t|
        [t.who, p] if (p.user_info == "GLOBAL" or p.user_info == t.user_info)
      end

      truths <+ provide_truth.payloads
    end

    bootstrap do
      truths <= [["tcp_in@localhost:8000", "global_truth", true, "GLOBAL"]]
    end

    def initialize node_name = "default", options = {}
      @name = node_name
      learn_about_tactics
      super options
      self.run_bg
    end

    def resolve what, user_info
      puts "Attempting to resolve '#{what}' with user info #{user_info}"
      options = {:what => what, :solver => ip_port, :user_info => user_info, :sync => true}
      question = Question.new options do |truths|
        puts "QUESTION #{what}"
        truths.to_a.each do |truth|
          truth_name, who, answer = truth
          puts "ANSWER:"
          puts "\ttruth: #{truth_name}"
          puts "\tprovider: #{who}"
          if answer.class == Array then
            puts "\tdata: #{answer.join(", ")}"
          else
            puts "\tdata: #{answer}"
          end
        end
      end
      question.stop

    end

    def shutdown
      puts "Shutting down the tactic solver"
    end

    def get_ip_port
      ip_port
    end

  private
    def explore_truth_space_for what, user_info
      @tactics.each do |tactic|
        tactic[:provides].each do |thing|
          if thing.match(what) then
            stdio <~ [["[#{tactic[:name]}] provides #{what}"]]
            tactic = Tactic.new tactic[:name], ip_port, @name, user_info
            tactic.execute what
          end
        end
      end
      []
    end

    def learn_about_tactics
      @tactics = []
      # Find and initialize all tactics
      Dir.foreach("tactics") do |dir_name|
        @tactics << (Tactic.provides dir_name, @name) if File.directory?("tactics/#{dir_name}") and !(dir_name =~ /\.{1,2}/)
      end
    end
  end
end
