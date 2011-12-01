require 'yaml'
require 'timeout'

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

    state do
      table :parameters, [:what, :provider] => [:value]
      table :needed_parameters, [:what] => [:requested]
    end

    bloom :parameters do
      # Request all needed truths
      need_truth <~ needed_parameters {|p|
        [@solver, [p.what, ip_port, @name]] unless p.requested
      }
      # Mark the parameters as requested
      needed_parameters <+- needed_parameters {|p|
        [p.what, true] unless p.requested
      }

      needed_truth_scratch <= needed_truth.payloads
      # Update the parameter
      parameters <+- (needed_parameters*needed_truth_scratch).
          pairs(:what => :what) {|p,t| [p.what, t.provider, t.truth]}
      # Mark the parameter as no longer needed
      needed_parameters <- (needed_truth_scratch*needed_parameters).
          pairs(:what => :what) {|nts, np| np}
    end

    def initialize dir_name, solver, options = {}
      @dir_name = dir_name
      @tactic_folder = File.join(File.dirname(__FILE__), "..", 
          "tactics/#{@dir_name}")
      @solver = solver
      @parameters = {}

      setup_tactic

      super options

      self.run_bg
    end

    def execute what
      set_the_magic_variables what

      # Do we provide what is required?
      does_provide_what = false
      @provides.each do |provide|
        does_provide_what = true if what =~ /^#{provide}/
      end
      print_error "does not provide #{what}" unless does_provide_what

      # Add all known data into the bloom system to bootstrap the resolution
      # process
      add_truth "port", "initial_value", @port
      add_truth "destination", "initial_value", @destination
      add_truth "domain", "initial_value", @domain
      add_truth "resource", "initial_value", @resource

      # Find what the tactic requires
      needed_parameters = requirements @requires
      # Add requirements
      needed_parameters.each {|p| add_requirement p}
    end

    def self.provides dir_name
      config = YAML::load(File.open("tactics/#{dir_name}/config.yml"))
      name = config['name']
      provides = []
      config['provides'].each {|something| provides << Regexp.new(something)}
      {:name => name, :provides => provides}

    rescue Errno::ENOENT
      print_error "Missing configuration file: " \
        + "Please ensure tactics/#{@name}/config.yml exists"

    end

  private
    # def add_truth truth, value
    #   if data[:new_truths] then
    #     new_truths = data[:new_truths]
    #     self.async_do {
    #       self.provide_truth <~ new_truths.map {|t|
    #         [@solver, [t[:what], @name, t[:value]]]
    #       }
    #     }
    #   end
    # end

    def add_truth truth, source, value
      self.async_do {
        # The magic values
        self.parameters <+ [[truth, source, value]]
      }
    end

    def add_requirement requirement
      self.async_do {
        self.needed_parameters <+ [[requirement, false]]
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
         "Local" => "local"}).each_pair do |arg, val|
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

      @provides = config['provides']
      @requires = config['requires']
      @dynamic_requirements = config['has_dynamic_requirements'] || false

      @executable = config['executable']

      check_file_exists @executable

      start_program

    rescue Errno::ENOENT
      Tactic.print_error "Missing configuration file: " \
          + "Please ensure #{@tactic_folder}/config.yml exists"

    end

    def start_program
      # Start the program
      @io = IO.popen("#{@tactic_folder}/#{@executable}")
      @io_thread = Thread.new(@io) do |io|
        keep_on_running = true
        while keep_on_running
          begin
            json_from_program = io.readline
            data = JSON.parse(json_from_program)

            keep_on_running = false if data[:terminate]

            deal_with data

          rescue e
            print_error "got malformed response from process."
          end
        end
        io.close()
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
      Tactic.print_error description
    end

    def deal_with data
      print_status "Dealing with data: #{data}"

      # Providing new thruths back to the system
      if data[:new_truths] then
        new_truths = data[:new_truths]
        self.async_do {
          self.provide_truth <~ new_truths.map {|t|
            [@solver, [t[:what], @name, t[:value]]]
          }
        }
      end

      # Requesting more truth data
      data[:needed_truths].each {|nd| add_requirement nd} if data[:needed_truths]
    end

  public
    def self.print_error description
      puts "ERROR [#{@name}]: #{description}"
      raise FailedTactic.new @name, description
    end
  end
end
