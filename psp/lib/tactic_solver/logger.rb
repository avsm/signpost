module TacticSolver
  # At the moment this is what is being logger:
  # # From the communication manager
  # - new_signpost_connection: signpost_name
  #     When a connection has been made with a remote signpost in the same
  #     domain.
  # - request_remote_signposts: signpost_name
  #     When the list of signposts known by a remote signpost in the same
  #     domain is requested
  # - return_list_of_signposts: signpost_name
  #     When a signpost returns the list of signposts it knows about
  # - request_remote_truths: signpost_name
  #     When a signpost requests the truths known by a remote signpost
  # - send_truth: signpost_name, *truth
  #     When a truth is passed on to a remote signpost. Constains the full
  #     truth data... this might be an issue in case sensitive data is
  #     passed... Should be changed before the system is put into production
  # - signpost_connection_closed: signpost_name
  #     When the connection to a remote signpost is terminated
  # - resolve_truth_remotely: signpost_name, what, user_info
  #     When a signpost requests a remote signpost to resolve a truth. Log on
  #     the signpost that requests the truth to be resolved.
  # - resolve_for_remote: signpost_name, what, user_info
  #     When a truth is to be resolved locally for a remote signpost
  # - return_list_of_truths: signpost_name
  #     When a signpost returns a list of the truths it knows to a remote
  #     signpost
  # - initiate_connection_to_signpost: signpost_name
  #     When a signpost initiates a connection to a remote signpost
  # - adding_remote_truth: signpost_name, *truth
  #     When a truth from a remote signpost is received and added to the local
  #     truth table. The signpost name is the name of the signpost that sent
  #     the truth.
  #
  # # From the tactic thread pool
  # - create_tactic_instance: tactic_name
  #     When an instance of a tactic is created.
  # - serve_truth_request: tactic_name, what, user_info
  #     When a tactic instance is used to resolve a truth
  #
  # # From the tactic scripts
  # - add_truth: tactic_name, truth, user_info, ttl
  #     When a tactic adds a new truth to the solver
  # - pass_truth_to_tactic: tactic_name, truth
  #     When a tactic passes on a truth from the solver to the tactic script
  # - add_observer: tactic_name, requirement
  #     When a tactic requests to become an observer of a truth value
  # - add_need: tactic_name, requirement
  #     When a tactic requests to become an observer of a truth
  # 
  class Logger
    def initialize log_file = "log/signpost.log", name = "AsOfYetUnknownNodeName"
      @_log_file = log_file
      @_name = name
      @_file = open_file @_log_file
    end

    def node_name= name
      @_name = name
    end

    # Logs message to disk.
    # It should be called with the log entry type as the first parameter, and
    # then the data as the subsequent parameters.
    # Example:: @logger.log "add_truth", truth_added, meta_data
    #
    # Will output:
    # NodeName;add_truth;TIMESTAMP;the_truth;meta_data
    #
    # General format:
    # NODE_NAME;ACTION;TIMESTAMP;ADDITIONAL_DATA;SPLIT;BY;COLON
    def log what, *data
      log_msg = "#{@_name};#{what};#{Time.now.to_i};#{data.join(";")}"
      @_file.puts log_msg
    end

    def close
      @_file.close
    end

  private
    def open_file file
      # Is it pointing to a directory?
      file = "#{file}/signpost.txt" if File.directory? file
      
      # Ensure the directory exists, and if not, create it
      dir_name = File.dirname(file)
      Dir.mkdir(dir_name) if !(File.exists?(dir_name) && File.directory?(dir_name))

      File.open(@_log_file, File::WRONLY|File::APPEND|File::CREAT)
    end
  end
end
