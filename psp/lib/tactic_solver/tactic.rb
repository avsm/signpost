require 'yaml'
require 'timeout'
require 'open3'

module TacticSolver
  # TacticCommunicatorDelegate
  # - register_ready_for_duty tactic_comm
  #     Called when the tactic script has connected to socket.
  #     It passes itself as the argument.
  # - received_data data
  #     Called with new data from the tactic
  class TacticCommunicator < EventMachine::Connection
    def initialize delegate
      @_delegate = delegate
      super
      @_delegate.register_ready_for_duty self
    end

    def stop_communicator
      close_connection_after_writing
    end

    def pass_on_data data
      send_data "#{data.to_json}\n"
    end

    def receive_data data
      data.split("\n").each do |d|
        begin
          e = JSON.parse(d)
          @_delegate.received_data e
        rescue JSON::ParserError
          $stderr.puts "Couldn't parse the input"
        end
      end
    end

    def unbind
      @_delegate.terminated
    end
    
  end

  # -----------------------------------------------------
  # TacticThreadOwner (the owner of the thread pool)
  # - tactic_thread_ready self
  #     Called when the tactic thread is ready for work
  # - name
  #     Returns the name of the node
  # TacticThreadDelegate (the tactic using the thread)
  # - tactic_received_data data
  #     Called when there is new data
  # - stop_tactic
  #     Terminates the tactic class
  class TacticThread
    def initialize dir_name, owner, is_daemon = false
      @_dir_name = dir_name
      @_owner = owner
      @_delegate = nil
      @_communicator = nil
      @_ready = false
      @_is_daemon = is_daemon

      setup_tactic

      if @_is_daemon then
        warm_up_the_daemon
      else
        warm_up_the_tactic
      end
    end

    def delegate= delegate
      @_delegate = delegate
    end

    def self.print_error name, message
      puts "ERROR [name]: #{message}"
    end

    def register_ready_for_duty tactic_communicator
      @_ready = true
      @_communicator = tactic_communicator
      if @_is_daemon then
        @_owner.daemon_thread_ready self
      else
        @_owner.tactic_thread_ready self
      end
    end

    # TacticCommunicatorDelegate method
    def received_data data
      # Let the delegate deal with the data
      @_delegate.tactic_received_data data

      # Check if the tactic is ready to be recycled
      if data["recycle"] then
        # Tell the delegate to shut down
        @_delegate.stop_tactic

        # Clean up the state
        @_delegate = nil

        # And let the tactic thread pool know
        # we are ready for reuse
        @_owner.tactic_thread_ready self
      end
    end

    # Called by the tactic when it wants to communicate
    # with the tactic script
    def send_data data
      @_communicator.pass_on_data data
    end

    def terminated
      puts "The tactic script #{@_name} terminated."
      # TODO: Inform the thread pool (owner) of the death
    end

    # Accessor methods
    def name
      @_name
    end
    def description
      @_description
    end
    def provides
      @_provides
    end
    def requires
      @_requires
    end
    def dir_name
      @_dir_name
    end
    def is_daemon?
      @_is_daemon
    end

  private
    def setup_tactic
      @_tactic_folder = File.join(File.dirname(__FILE__), "..", "..", 
          "tactics/#{@_dir_name}")
      config_path = @_tactic_folder + "/config.yml"
      config = YAML::load(File.open(config_path))
      @_name = config['name']
      @_description = config['description']

      @_provides = config['provides'].map {|p| Tactic.deal_with_magic p, @_owner.name}
      @_requires = config['requires']
      @_executable = config['executable']
      # If the tactic has listed an executable, then we need to check for it
      check_file_exists @_executable if @_executable

      @_daemon = config['daemon']
      # If the tactic has listed a daemon, then we need to check for it
      check_file_exists @_daemon if @_daemon

      # If the tactic has listed that is provides something, but doesn't
      # provide an executable, then that is wrong! Remember, that only tactic
      # executables can be relied on to provide truths on demand.
      if @_provides and !@_executable then
        error_msg = "Has a provide clause, but does not " \
            + "have an executable tactic."
        error_msg += " Recall that daemons cannot provide on demand truths" if @_daemon
        TacticThread.print_error @_name, error_msg
      end

    rescue Errno::ENOENT
      TacticThread.print_error @_name, "Missing configuration file: " \
          + "Please ensure #{@_tactic_folder}/config.yml exists"

    end

    def socket_name
      unless @socket_name then
        long_name = (0...50).map{ ('a'..'z').to_a[rand(26)] }.join
        @socket_name = "/tmp/signpost-#{long_name}.sock"
      end
      @socket_name
    end

    def warm_up_the_tactic
      warm_up_the_engine @_executable
    end

    def warm_up_the_daemon
      warm_up_the_engine @_daemon
    end

    def warm_up_the_engine executable
      EventMachine::start_unix_domain_server(socket_name, TacticCommunicator, self)
      File.chmod(0777, socket_name)
      full_executable = "#{@_tactic_folder}/#{executable} #{socket_name}"
      IO.popen(full_executable)
      # tactic_script = fork {exec "#{@_tactic_folder}/#{@_executable} #{socket_name}"}
      # Process.detach(tactic_script)
    end

    def check_file_exists *files
      files.each do |file|
        file_path = "#{@_tactic_folder}/#{file}"
        print_error "#{file} is missing" unless File.exists? file_path
      end
    end
  end

  # -----------------------------------------------------
  
  class FailedTactic < Exception
    def initialize tactic, description
      @tactic = tactic
      @desc = description
    end

    def to_s
      "Tactic #{@tactic} failed: #{@desc}"
    end
  end
  
  # -----------------------------------------------------

  class Tactic
    include Bud
    include TacticProtocol

    #---------------------------

    bloom :parameters do
      needed_truth_scratch <= needed_truth.payloads
    end
  
    bootstrap do
      perform_bootstrapping if @_perform_delayed_execution
    end

    #---------------------------
    
    def initialize tactic_thread, solver, node_name, user_info, options = {}
      # For tactics
      @_user_info = user_info
      @_what = options[:what] || nil

      # Both tactics and daemons
      @_tactic_thread = tactic_thread
      @_node_name = node_name
      @_solver = solver
      @_is_daemon = @_tactic_thread.is_daemon?
      @_perform_delayed_execution = @_is_daemon ? true : (@_what ? true : false)

      super options
      register_callbacks
      
      # Register with the tactic thread, so we get the delegate callbacks
      @_tactic_thread.delegate = self

      self.run_bg
    end

    def register_callbacks
      # When we get truths we need, then pass them on to the program
      self.register_callback(:needed_truth_scratch) do |data|
        data.to_a.each do |d|
          what, source, user_info, value = d
          pass_on_truth what, source, value
        end
      end
    end

    def stop_tactic
      # Remove subscriptions from solver
      self.sync_do {remove_subscriptions <~ [[@_solver, [ip_port]]]}
      @me = self
      EM::add_timer(1) do
        @me.stop
      end
    end

    #---------------------------

    # TacticThreadDelegate:
    def tactic_received_data data
      self.deal_with data
    end

    # ---------------------------------------------------------
    # As part of their setup tactics perform a system bootstrap
    # where they declare their requirements to the solver, and
    # also pass on initial data to the tactic.
    # Daemons also bootstrap, but perform a somewhat different
    # bootstrapping dance.
    # ---------------------------------------------------------

    def perform_bootstrapping
      @_perform_delayed_execution = false
      @_is_daemon ? daemon_bootstrap : tactic_bootstrapping 
    end

    # ---------------------------------------------------------
    # Tactics bootstrapping:
    # ---------------------------------------------------------
    
    def tactic_bootstrapping
      execute @_what
    end

    def execute what
      @_what = what
      # Do we provide what is required?
      does_provide_what = false
      @_tactic_thread.provides.each do |provide|
        does_provide_what = true if @_what =~ /^#{provide}/
      end

      @_name = @_tactic_thread.name

      unless does_provide_what then
        print_status "does not provide #{@_what}" 
        raise FailedTactic.new(@_name, "does not provide #{@_what}")
        return

      else
        print_status "does provide #{@_what}"

      end

      set_the_magic_variables what

      # Find what the tactic requires
      needed_parameters = requirements @_tactic_thread.requires
      # Add requirements
      needed_parameters.each {|p| add_requirement p}

      send_initial_data
    end

    def send_initial_data
      # Pass standard facts to the tactic
      pass_on_truths [["is_daemon", "initial_value", false],
                      ["what", "initial_value", @_what],
                      ["port", "initial_value", @_port],
                      ["destination", "initial_value", @_destination],
                      ["domain", "initial_value", @_domain],
                      ["resource", "initial_value", @_resource],
                      ["user", "initial_value", @_user_info],
                      ["node_name", "initial_value", @_node_name]]
    end

    # ---------------------------------------------------------
    # Daemons bootstrapping:
    # ---------------------------------------------------------

    def daemon_bootstrap
      @_name = @_tactic_thread.name
      
      # Pass standard facts to the tactic
      pass_on_truths [["is_daemon", "initial_value", true],
                      ["node_name", "initial_value", @_node_name]]
    end

    # ---------------------------------------------------------
   
    # Takes data received from the tactic or daemon instance,
    # and performs the required action. That might be to forward
    # data provided to the resolver, or request more information,
    # or for that matter to become an observer of a resource type.
    def deal_with data
      # Providing new thruths back to the system
      if data["provide_truths"] then
        new_truths = data["provide_truths"]
        new_truths.each {|truth| 
          user_info = truth["global"] == true ? "GLOBAL" : @_user_info
          add_truth deal_with_magic(truth["what"]), truth["value"], user_info
        }
      end

      # Requesting more truth data
      if data["need_truths"] then
        needs = data["need_truths"]
        needs.each {|nd| add_requirement need_from nd}
      end

      # Become a truth observer
      if data["observe"] then
        observes = data["observe"]
        observes.each {|t| add_observer observation_from t}
      end

      # Log messages
      data["logs"].each {|log_msg| print_status log_msg} if data["logs"]
    end

    def self.print_error name, description
      puts "ERROR [#{name}]: #{description}"
      raise FailedTactic.new name, description
    end

    def communication_agent= agent
      @_communication_agent = agent
      # Some times we have received data before we are ready
      # with a communication agent.
      # If that has been the case, then we need to send on the
      # data once we have a communication agent.
      if @_pending_pass_on_data then
        @_pending_pass_on_data.each do |data|
          @_communication_agent.pass_on_data data
        end
      end
    end

    def self.deal_with_magic provision, node_name
      prov = provision
      ({"Local" => node_name}).each_pair do |arg, val|
         prov.gsub!(arg, val)
      end
      prov
    end

    def self.provides dir_name, node_name
      config = YAML::load(File.open("tactics/#{dir_name}/config.yml"))
      name = config['name']
      provides = []
      config['provides'].each {|something| 
        provides << Regexp.new("^#{Tactic.deal_with_magic(something, node_name)}")
      }
      has_daemon = config["daemon"] ? true : false
      {
        :name => name, 
        :provides => provides, 
        :dir_name => dir_name, 
        :has_daemon => has_daemon
      }

    rescue Errno::ENOENT
      print_error "Missing configuration file: " \
        + "Please ensure tactics/#{@_name}/config.yml exists"

    end

  private
    def deal_with_magic provision
      Tactic.deal_with_magic provision, @_node_name
    end

    def observation_from data
      if (!data["port"] and
          !data["domain"] and
          !data["destination"]) then
        data["destination"] = "ANY"
      end
      need_from data
    end

    def need_from data
      what = data["what"]
      res = if data["destination"] then
        "#{what}@#{data["destination"]}"
      elsif data["domain"] and data["port"] then
        "#{what}@#{data["domain"]}:#{data["port"]}"
      elsif data["domain"] then
        "#{what}@#{data["domain"]}"
      elsif data["port"] then
        "#{what}@#{@_domain}:#{data["port"]}"
      else
        "#{what}@#{@_destination}"
      end
      res
    end

    def add_truth truth, value, user_info
      self.sync_do {
        self.provide_truth <~ [[@_solver, [truth, @_name, user_info, value]]]
      }
    end

    def pass_on_truths truth_vals
      truths = []
      truth_vals.each do |truth, source, value|
        new_truth = {
          :what => truth,
          :source => source,
          :value => value
        }
        truths << new_truth
      end
      data = {:truths => truths}
      @_tactic_thread.send_data data
    end

    def pass_on_truth truth, source, value
      pass_on_truths [[truth, source, value]]
    end

    def add_observer requirement
      self.sync_do {self.observe_truth <~ [[@_solver, [requirement, ip_port, @_user_info, @_name]]]}
    end

    def add_requirement requirement
      self.sync_do {self.need_truth <~ [[@_solver, [requirement, ip_port, @_user_info, @_name]]]}
    end

    def requirements requires
      return [] unless requires
      needed_parameters = []
      requires.each do |requirement|
        adapted_requirement = requirement
        ({"Port" => @_port, "Destination" => @_destination,
         "Domain" => @_domain, "Resource" => @_resource,
         "Local" => @_node_name}).each_pair do |arg, val|
          while (adapted_requirement =~ 
              /([\w\d@\-\_\.\:]*)#{arg.capitalize}([\w\d@\-\_\.\:]*)/)
            adapted_requirement = "#{$1}#{val}#{$2}"
          end
        end
        needed_parameters << adapted_requirement
      end
      needed_parameters
    end

    def set_the_magic_variables what
      vars = Helpers.magic_variables_from what
      @_domain = vars[:domain]
      @_port = vars[:port]
      @_destination = vars[:destination]
      @_resource = vars[:resource]
    end

    def print_status description
      name = "[#{@_name}#{@_is_daemon ? " daemon" : ""}]"
      puts "STATUS #{name}: #{description}"
    end

    def print_error description
      name = "[#{@_name}#{@_is_daemon ? " daemon" : ""}]"
      Tactic.print_error name, description
    end

  end
end
