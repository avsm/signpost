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

    state do
      table :parameters, [:what, :provider] => [:value]
    end

    bloom :parameters do
      needed_truth_scratch <= needed_truth.payloads
      # Pass the parameter to the tactic program
      stdio <~ needed_truth_scratch do |t|
        [["Got truth: #{t}"]]
      end
    end

    #---------------------------
    
    def initialize dir_name, solver, node_name, options = {}
      @dir_name = dir_name
      @node_name = node_name
      @tactic_folder = File.join(File.dirname(__FILE__), "..", 
          "tactics/#{@dir_name}")
      @solver = solver
      @parameters = {}

      setup_tactic

      super options
      self.run_bg
    end

    def shut_down
      self.stop
      @io_in.close if @io_in
      @io_out.close if @io_out
      @io_err.close if @io_err
      @thread_out.terminate
      @thread_err.terminate
    end

    #---------------------------

    def execute what
      start_program

      set_the_magic_variables what

      # Do we provide what is required?
      does_provide_what = false
      @provides.each do |provide|
        does_provide_what = true if what =~ /^#{provide}/
      end
      unless does_provide_what then
        puts "[#{@name}] does not provide #{what}" 
        shut_down
        return
      end

      # Add all known data into the bloom system to bootstrap the resolution
      # process
      pass_on_truth "what", "initial_value", what
      pass_on_truth "port", "initial_value", @port
      pass_on_truth "destination", "initial_value", @destination
      pass_on_truth "domain", "initial_value", @domain
      pass_on_truth "resource", "initial_value", @resource

      # Find what the tactic requires
      needed_parameters = requirements @requires
      # Add requirements
      needed_parameters.each {|p| add_requirement p}
    end

    def self.provides dir_name, node_name
      config = YAML::load(File.open("tactics/#{dir_name}/config.yml"))
      name = config['name']
      provides = []
      config['provides'].each {|something| 
        provides << Regexp.new(Tactic.deal_with_magic(something, node_name))
      }
      {:name => name, :provides => provides}

    rescue Errno::ENOENT
      print_error "Missing configuration file: " \
        + "Please ensure tactics/#{@name}/config.yml exists"

    end

    def deal_with data
      # Providing new thruths back to the system
      if data["provide_truths"] then
        new_truths = data["provide_truths"]
        new_truths.each {|truth| add_truth deal_with_magic(truth["what"]), truth["value"]}
      end

      # Requesting more truth data
      if data["need_truths"] then
        needs = data["need_truths"]
        needs.each {|nd| add_requirement need_from nd}
      end
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
      Tactic.deal_with_magic provision, @node_name
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
        "#{what}@#{@domain}:#{data["port"]}"
      else
        "#{what}@#{@destination}"
      end
      puts "Returning data: #{res}, got data:"
      pp data
      res
    end

    def add_truth truth, value
      puts "Adding new truth: #{truth} -> #{value}"
      self.async_do {
        self.provide_truth <~ [[@solver, [truth, @name, value]]]
      }
    end

    def pass_on_truth truth, source, value
      new_truth = {
        :what => truth,
        :source => source,
        :value => value
      }
      data = {:truths => [new_truth]}
      @io_in.puts data.to_json
    end

    def add_requirement requirement
      self.async_do {
        self.need_truth <~ [[@solver, [requirement, ip_port, @name]]]
      }
    end

    def requirements requires
      return [] unless requires
      # TODO: What should "local" be swapped with?
      needed_parameters = []
      requires.each do |requirement|
        adapted_requirement = requirement
        ({"Port" => @port, "Destination" => @destination,
         "Domain" => @domain, "Resource" => @resource,
         "Local" => @node_name}).each_pair do |arg, val|
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
      @domain = vars[:domain]
      @port = vars[:port]
      @destination = vars[:destination]
      @resource = vars[:resource]
    end

    def setup_tactic
      config_path = @tactic_folder + "/config.yml"
      config = YAML::load(File.open(config_path))
      @name = config['name']
      @description = config['description']

      @provides = config['provides'].map {|p| deal_with_magic p}
      @requires = config['requires']
      @dynamic_requirements = config['has_dynamic_requirements'] || false

      @executable = config['executable']

      check_file_exists @executable

    rescue Errno::ENOENT
      Tactic.print_error "Missing configuration file: " \
          + "Please ensure #{@tactic_folder}/config.yml exists"

    end

    def start_program
      # Start the program
      @io_in, @io_out, @io_err = Open3.popen3("#{@tactic_folder}/#{@executable}")
      @io_in.sync = true

      @thread_out = Thread.new(@io_out, self) do |out, tactic|
        while true
          begin
            json_from_program = out.gets
            data = JSON.parse(json_from_program)

            tactic.deal_with data

          rescue e
            puts "ERROR [#{@name}]: got malformed response from process."

          end
        end
      end

      @thread_err = Thread.new(@io_err) do |err|
        while true
          begin
            error_text = err.gets
            puts "STDERR [#{@name}] : #{error_text}" unless error_text.strip.chomp == ""

          rescue e
            puts "ERROR [#{@name}]: reading error in STDERR reading thread for #{@name}"

          end
        end
      end
    end

    def check_file_exists *files
      files.each do |file|
        file_path = File.join(File.dirname(__FILE__), "..", 
            "tactics/#{@dir_name}/#{file}")
        print_error "#{file} is missing" unless File.exists? file_path
      end
    end

    def print_status description
        puts "STATUS [#{@name}]: #{description}"
    end

    def print_error description
      Tactic.print_error @name, description
    end

  end
end
