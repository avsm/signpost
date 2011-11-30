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
      need_truth <~ needed_parameters {|p| [@solver, [p.what, ip_port, @name]] unless p.requested}
      # Mark the parameters as requested
      needed_parameters <+- needed_parameters {|p| [p.what, true] unless p.requested}

      needed_truth_scratch <= needed_truth.payloads
      # Update the parameter
      parameters <+- (needed_parameters*needed_truth_scratch).pairs(:what => :what) {|p,t| [p.what, t.provider, t.truth]}
      # Mark the parameter as no longer needed
      needed_parameters <- (needed_truth_scratch*needed_parameters).pairs(:what => :what) {|nts, np| np}

      # stdio <~ parameters.inspected
      # stdio <~ needed_parameters.inspected
    end

    def initialize name, solver, options = {}
      @name = name
      @solver = solver
      @parameters = {}

      setup_tactic

      super options

      self.run_bg
    end

    def execute what, *arguments
      print_status "trying to execute #{what}. Received arguments: #{arguments.join(", ")}"

      # Do we provide what is required?
      if @provides[what] then
        required_arguments = @provides[what]['arguments']
        if required_arguments.length == arguments.size then
          required_arguments.each_index do |index|
            @parameters[required_arguments[index]] = arguments[index]
          end

        else
          print_error "You didn't provide the correct number of arguments. #{what} expects: #{required_arguments.join(", ")}"

        end

      else
        print_error "#{what} is not provided"
          
      end
      
      # Look for matches of the arguments in the requirements
      needed_parameters = []
      @requires.each do |requirement|
        adapted_requirement = requirement
        @parameters.each_pair do |arg, val|
          if adapted_requirement =~ /([\w\d@\-\_\.\:]*)#{arg.capitalize}([\w\d@\-\_\.\:]*)/
            adapted_requirement = "#{$1}#{val}#{$2}"
          end
        end
        needed_parameters << adapted_requirement
      end

      # Add all known data into the bloom system to bootstrap the resolution
      # process
      self.async_do {
        @parameters.each_pair do |name, val|
          self.parameters <+ [[name, "initial_argument", val]]
        end
        needed_parameters.each do |param|
          self.needed_parameters <+ [[param, false]]
        end
      }
    end

    def self.provides dir_name
      config = YAML::load(File.open("tactics/#{dir_name}/config.yml"))
      name = config['name']
      provides = []
      config['provides'].each_key {|something| provides << Regexp.new(something)}
      {:name => name, :provides => provides}

    rescue Errno::ENOENT
      self.print_error "Missing configuration file: Please ensure tactics/#{@name}/config.yml exists"

    end

  private
    def setup_tactic
      config = YAML::load(File.open("tactics/#{@name}/config.yml"))
      @name = config['name']
      @description = config['description']

      @provides = config['provides']
      @requires = config['requires']
      @dynamic_requirements = config['has_dynamic_requirements'] || false

      @executable = config['executable']

      check_file_exists @executable

    rescue Errno::ENOENT
      print_error "Missing configuration file: Please ensure tactics/#{@name}/config.yml exists"

    end

    def check_file_exists *files
      files.each do |file|
        print_error "#{file} is missing" unless File.exists? "tactics/#{@name}/#{file}"
      end
    end

    def print_status description
        puts "STATUS [#{@name}]: #{description}"
    end

    def self.print_error description
        puts "ERROR [#{@name}]: #{description}"
        raise FailedTactic.new @name, description
    end

    def print_error description
      self.print_error description
    end
  end
end
