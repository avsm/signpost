module TacticSolver
  class Solver
    include Bud
    include TacticProtocol

    state do
      # These are the truths that we know
      # We know WHERE they are valid, i.e. locally, or on host B
      # We know WHAT sort of truth they are
      # and we know the TRUTH itself
      table :truths, [:where, :what] => [:truth]

      # These are the truths needed
      # We know WHO needs the truth
      # We know WHAT truth is needed
      # and we know WHERE the truth holds, i.e. if it should be a local
      #     truth or a truth on host B
      table :truths_needed, [:who, :what, :where]

      # These are the services provided
      # We know WHO provices the service
      # and WHAT service they provide
      table :providers, [:who, :what]
    end

    def initialize options = {}
      puts "Setting up solver"
      super options
    end

    def setup_and_run
      puts "Setting up and starting solver"
      self.run_bg
    end

    def resolve what, address, port = nil
      puts "Will try to resolve a #{what} to #{address}#{port ? ":#{port}" : ""}"
    end

    def shutdown
      puts "Shutting down this mess"
    end
  end
end
