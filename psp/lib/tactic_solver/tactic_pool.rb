module TacticSolver
  class TacticPool
    def initialize node_name, ip_port
      @_node_name = node_name
      @_ip_port = ip_port

      # This is where tactics are stored
      @_tactic_pool = {}
      @_tactics = []

      learn_about_tactics
    end

    def explore_truth_space_for what, user_info
      @_tactics.each do |tactic|
        tactic[:provides].each do |thing|
          if thing.match(what) then
            spawn_execution_for tactic, what, user_info
          end
        end
      end
    end
    
    def tactics
      @_tactics
    end

    # -----------------------------------------
    # Delegate methods for TacticThread
    # -----------------------------------------

    # TacticThreadOwner:
    def name
      @_node_name
    end

    # TacticThreadOwner:
    def tactic_thread_ready tactic
      pool = pool_for_name tactic.dir_name
      pool.push tactic

    end

    # -----------------------------------------
    
  private
    def spawn_execution_for tactic, what, user_info
      pool = pool_for_name tactic[:dir_name]

      # There are no tactics available. Instead queue the
      # request, and spawn a tactic instance.
      if pool.empty? then
        puts "[INFO]: Expanding tactic thread pool with tactic '#{tactic[:name]}'"
        TacticThread.new tactic[:dir_name], self

      end

      pool.pop do |tactic_instance|
        serve_tactic_request tactic_instance, what, user_info
      end
    end

    def pool_for_name name
      @_tactic_pool[name] ||= EM::Queue.new
      @_tactic_pool[name]
    end

    def serve_tactic_request tactic_thread, what, user_info
      options = {:what => what}
      Tactic.new tactic_thread, @_ip_port, @_node_name, user_info, options
    end

    def learn_about_tactics
      # Find and initialize all tactics
      Dir.foreach("tactics") do |dir_name|
        @_tactics << (Tactic.provides dir_name, @_node_name) if File.directory?("tactics/#{dir_name}") and !(dir_name =~ /\.{1,2}/)
      end
    end
  end
end
