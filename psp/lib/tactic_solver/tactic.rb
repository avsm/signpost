require 'yaml'
require 'timeout'

module TacticSolver
  class Tactic
    include Bud
    include TacticProtocol

    bootstrap do
      tactic_signup <~ [[@tactic_solver, [ip_port, @name]]]
    end

    def initialize name, options = {}
      @name = name
      setup_tactic
      super options
    end

  private
    def setup_tactic
      config = YAML::load(File.open("tactics/#{@name}/config.yml"))
      @prober = config['prober']
      @actuator = config['actuator']
      @background_process = config['daemon']
      @description = config['description']
      @supported_interfaces = config['supported_interfaces']
      @timeout = 2 * 60 # 2 minute timeout...

      check_file_exists @prober, @actuator

      # Setup background process
      if @background_process then
        status = `tactics/#{@name}/#{@background_process['start']}`
        unless status == "" then
          print_error "background process failed to start: #{status}"
        end
      end

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

    def print_error description
        puts "ERROR [#{@name}]: #{description}"
    end
  end
end
