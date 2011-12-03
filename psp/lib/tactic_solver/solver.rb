module TacticSolver
  class Solver
    include Bud
    include TacticProtocol

    attr_reader :tactics

    state do
      # These are the truths that we know
      # We know WHAT sort of truth they are
      # and we know the TRUTH itself
      table :truths, [:what, :provider] => [:truth]

      # These are the truths that are subscribed to
      # We know WHAT truth is needed
      # and WHO needs the truth
      table :truth_subscribers, [:what, :who] => [:who_name]

      # These are the services provided
      # We know WHAT services are provided
      # and WHO provices the service
      table :providers, [:what] => [:who]

      scratch :satisfiable_truth_needs, [:who, :what] => [:truth]
    end

    # Exchange truths with tactics
    bloom :tactic_comms do
      need_truth_scratch <= need_truth.payloads

      truth_subscribers <+- need_truth_scratch

      # Let's see if we can satisfy the truths directly from our truth cache
      satisfiable_truth_needs <= (truths*need_truth_scratch).
          pairs(:what => :what) {|t, nt| [nt.who, t.what, t]}
      needed_truth <~ satisfiable_truth_needs {|stn| [stn.who, stn.truth]}

      # Find needs that we cannot satisfy, and register them
      temp :dev_null <= need_truth_scratch do |nt|
        explore_truth_space_for nt.what unless satisfiable_truth_needs.exists? {|s|
          s.what == nt.what
        }
      end

      provide_truth_scratch <= provide_truth.payloads
      truths <= provide_truth_scratch
      needed_truth <~ (provide_truth_scratch*truth_subscribers).pairs(:what => :what) do |p,t|
        [t.who, p]
      end

      truths <= provide_truth.payloads

      # stdio <~ truths.inspected
      # stdio <~ truth_subscribers.inspected
    end

    bootstrap do
      truths <= [["tcp_in@localhost:8000", "global_truth", true]]
    end

    def initialize node_name = "default", options = {}
      @name = node_name
      learn_about_tactics
      super options
      self.run_bg
    end

    def resolve what
      puts "Attempting to resolve '#{what}'"
      question = Question.new what, ip_port do |truths|
        puts "QUESTION #{what}"
        truths.to_a.each do |truth|
          truth_name, who, answer = truth
          puts "ANSWER:"
          puts "\ttruth: #{truth_name}"
          puts "\tprovider: #{who}"
          puts "\tdata: #{answer}"
        end
        question.stop
      end

    end

    def shutdown
      puts "Shutting down this mess"
    end

  private
    def explore_truth_space_for what
      @tactics.each do |tactic|
        tactic[:provides].each do |thing|
          if thing.match(what) then
            stdio <~ [["[#{tactic[:name]}] provides #{what}"]]
            tactic = Tactic.new tactic[:name], ip_port, @name
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
