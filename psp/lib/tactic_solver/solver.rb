module TacticSolver
  class Solver
    include Bud
    include TacticProtocol

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
      satisfiable_truth_needs <= (truths*need_truth_scratch).pairs(:what => :what) {|t, nt| [nt.who, t.what, t]}
      needed_truth <~ satisfiable_truth_needs {|stn| [stn.who, stn.truth]}

      # Find needs that we cannot satisfy, and register them
      temp :dev_null <= need_truth_scratch do |nt|
        explore_truth_space_for nt.what unless satisfiable_truth_needs.exists? {|s| s.what == nt.what}
      end
    end

    bootstrap do
      truths <= [["tcp_in_8000@localhost", "global_truth", true]]
    end

    def initialize options = {}
      learn_about_tactics
      super options
      self.run_bg
    end

    def resolve what, address, port = 8000
      puts "Will try to resolve a #{what} to #{address}#{port ? ":#{port}" : ""}"
      tactic = Tactic.new "direct_connection", ip_port
      tactic.execute what, address, port

    end

    def shutdown
      puts "Shutting down this mess"
    end

  private
    def explore_truth_space_for what
      @tactics.each do |tactic|
        tactic[:provides].each do |thing|
          if thing.match(what) then
            # tactic = Tactic.new tactic[:name], ip_port
            stdio <~ [["#{what} is provided by #{tactic[:name]}"]]
          else
            stdio <~ [["#{what} is NOT provided by #{tactic[:name]}"]]
          end
        end
      end
      []
    end

    def learn_about_tactics
      @tactics = []
      # Find and initialize all tactics
      Dir.foreach("tactics") do |dir_name|
        @tactics << (Tactic.provides dir_name) if File.directory?("tactics/#{dir_name}") and !(dir_name =~ /\.{1,2}/)
      end
      pp @tactics
    end
  end
end
