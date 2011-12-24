require 'yaml'
require 'timeout'
require 'open3'

module TacticSolver
  class FailedTactic < Exception
    def initialize tactic, description
      @tactic = tactic
      @desc = description
    end

    def to_s
      "Tactic #{@tactic} failed: #{@desc}"
    end
  end

  class Tactic
    include Bud
    include TacticProtocol

    #---------------------------

    bloom :parameters do
      needed_truth_scratch <= needed_truth.payloads
    end

    #---------------------------
    
    def initialize dir_name, solver, node_name, user_info, options = {}
      @_dir_name = dir_name
      @_node_name = node_name
      @_tactic_folder = File.join(File.dirname(__FILE__), "..", "..", 
          "tactics/#{@_dir_name}")
      @_solver = solver
      @_parameters = {}
      @_user_info = user_info

      setup_tactic

      super options
      self.run_bg
      register_callbacks
    end

    def register_callbacks
      # When we get truths we need, then pass them on to the program
      self.register_callback(:needed_truth_scratch) do |data|
        # TODO: Make this happen in a thread?
        data.to_a.each do |d|
          what, source, user_info, value = d
          pass_on_truth what, source, value
        end
      end
    end

    def shut_down
      # Remove subscriptions from solver
      self.sync_do {remove_subscriptions <~ [[@_solver, [ip_port]]]}

      self.stop
      @_io_in.close if @_io_in
      @_io_out.close if @_io_out
      @_io_err.close if @_io_err
      @_thread_out.terminate
      @_thread_err.terminate
    end

    #---------------------------

    def execute what
      @_what = what
      # Do we provide what is required?
      does_provide_what = false
      @_provides.each do |provide|
        does_provide_what = true if @_what =~ /^#{provide}/
      end

      unless does_provide_what then
        puts "[#{@_name}] does not provide #{@_what}" 
        raise FailedTactic.new(@_name, "does not provide #{@_what}")
        return

      else
        puts "[#{@_name}] does provide #{@_what}"

      end

      set_the_magic_variables what
      start_program

      # Add all known data into the bloom system to bootstrap the resolution
      # process
      pass_on_truth "what", "initial_value", @_what
      pass_on_truth "port", "initial_value", @_port
      pass_on_truth "destination", "initial_value", @_destination
      pass_on_truth "domain", "initial_value", @_domain
      pass_on_truth "resource", "initial_value", @_resource
      pass_on_truth "user", "initial_value", @_user_info

      # Find what the tactic requires
      needed_parameters = requirements @_requires
      # Add requirements
      needed_parameters.each {|p| add_requirement p}
    end

    def self.provides dir_name, node_name
      config = YAML::load(File.open("tactics/#{dir_name}/config.yml"))
      name = config['name']
      provides = []
      config['provides'].each {|something| 
        provides << Regexp.new("^#{Tactic.deal_with_magic(something, node_name)}")
      }
      {:name => name, :provides => provides}

    rescue Errno::ENOENT
      print_error "Missing configuration file: " \
        + "Please ensure tactics/#{@_name}/config.yml exists"

    end

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

      # Log messages
      data["logs"].each {|log_msg| print_status log_msg} if data["logs"]
    end

    def self.print_error name, description
      puts "ERROR [#{name}]: #{description}"
      raise FailedTactic.new name, description
    end

  private
    def self.deal_with_magic provision, node_name
      prov = provision
      ({"Local" => node_name}).each_pair do |arg, val|
         prov.gsub!(arg, val)
      end
      prov
    end

    def deal_with_magic provision
      Tactic.deal_with_magic provision, @_node_name
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

    def pass_on_truth truth, source, value
      new_truth = {
        :what => truth,
        :source => source,
        :value => value
      }
      data = {:truths => [new_truth]}
      @_io_in.puts data.to_json
    end

    def add_requirement requirement
      print_status "Adding requirement #{requirement}"
      self.sync_do {
        self.need_truth <~ [[@_solver, [requirement, ip_port, @_user_info, @_name]]]
      }
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

    def setup_tactic
      config_path = @_tactic_folder + "/config.yml"
      config = YAML::load(File.open(config_path))
      @_name = config['name']
      @_description = config['description']

      @_provides = config['provides'].map {|p| deal_with_magic p}
      @_requires = config['requires']
      @_dynamic_requirements = config['has_dynamic_requirements'] || false

      @_executable = config['executable']

      check_file_exists @_executable

    rescue Errno::ENOENT
      Tactic.print_error @_name, "Missing configuration file: " \
          + "Please ensure #{@_tactic_folder}/config.yml exists"

    end

    def start_program
      # Start the program
      @_io_in, @_io_out, @_io_err = Open3.popen3("#{@_tactic_folder}/#{@_executable}")
      @_io_in.sync = true

      @_thread_out = Thread.new(@_io_out, self) do |out, tactic|
        while true
          begin
            json_from_program = out.gets
            data = JSON.parse(json_from_program)

            tactic.deal_with data

          rescue e
            puts "ERROR [#{@_name}]: got malformed response from process."

          end
        end
      end

      @_thread_err = Thread.new(@_io_err) do |err|
        while true
          begin
            error_text = err.gets
            puts "STDERR [#{@_name}] : #{error_text}" unless error_text.strip.chomp == ""

          rescue e
            puts "ERROR [#{@_name}]: reading error in STDERR reading thread for #{@_name}"

          end
        end
      end
    end

    def check_file_exists *files
      files.each do |file|
        file_path = "#{@_tactic_folder}/#{file}"
        print_error "#{file} is missing" unless File.exists? file_path
      end
    end

    def print_status description
        puts "STATUS [#{@_name}]: #{description}"
    end

    def print_error description
      Tactic.print_error @_name, description
    end

  end
end
