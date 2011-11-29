module TacticSolver
  class Solver
    include Bud
    include TacticProtocol

    state do
      # These are the truths that we know
      # We know WHAT sort of truth they are
      # We know WHERE they are valid, i.e. locally, or on host B
      # and we know the TRUTH itself
      table :truths, [:what, :where] => [:truth]

      # These are the truths needed
      # We know WHAT truth is needed
      # WHERE the truth should hold, i.e. if it should be a local
      #     truth or a truth on host B
      # and WHO needs the truth
      table :truths_needed, [:what, :where] => [:who]

      # These are the services provided
      # We know WHAT services are provided
      # and WHO provices the service
      table :providers, [:what] => [:who]
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
