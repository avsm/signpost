module TacticSolver
  class TacticSolverException < Exception 
  end
  class ResourceTypeException < TacticSolverException 
  end

  class Helpers
    def self.magic_variables_from what
      # We provide some magic variables:
      # Destination, Domain, and Port.
      # 
      # Example:
      #   
      #   service@localhost:8000
      #
      # Destination: localhost:8000
      # Domain: localhost
      # Port: 8000

      if what =~ /([[:graph:]]*)@(([[:alnum:]\.\-]*)(:([\d]*))?)/ then
        response = {}

        resource = $1
        destination = $2
        domain = $3
        port = $5
        response[:resource] = resource
        response[:destination] = destination
        response[:domain] = domain
        response[:port] = port.to_i if port
        response
      else
        raise ResourceTypeException.new

      end

    end
  end
end
