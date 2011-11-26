require 'yaml'

class Tactic
  include Bud

  state do
    scratch :possible_connections, [:interface, :to]
  end
  
  def initialize name, tactic_solver, options = {}
    puts "> initializing tactic: #{name}"
    @name = name
    @tactic_solver = tactic_solver
    setup_tactic
    super options
  end

  bloom do
    ###
  end

  def post_setup
    self.register_callback(:possible_connections) do |entries|
      entries.each do |entry|
        evaluate_input entry
      end
    end
    self.run_bg
  end

  def input_to_evaluate interface, to
    self.sync_do {
      possible_connections <+ [[interface, to]]
    }
  end

  def tear_down_tactic
    if @background_process then
      status = `./tactics/#{@name}/#{@background_process['stop']}`
      unless status == "" then
        print_error "background process failed to terminate cleanly: #{status}"
      end
    end
  end

  private
  def setup_tactic
    config = YAML::load(File.open("tactics/#{@name}/config.yml"))
    @prober = config['prober']
    @actuator = config['actuator']
    @background_process = config['daemon']
    @description = config['description']
    @supported_interfaces = config['supported_interfaces']

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

  def evaluate_input entry
    if @supported_interfaces.include?(entry.interface) then
      puts "[#{@name}]: Evaluating possibility of connecting to #{entry.to} through #{entry.interface}"
      result = `tactics/#{@name}/#{@prober} #{entry.interface} #{entry.to}`
      if (result =~ /SUCCESS ([\d]*) ([\d]*) ([\d]*)/) != nil
        latency = $1
        bandwidth = $2
        overhead = $3
        data = {
          :client => entry.to,
          :strategy => @name,
          :interface => entry.interface,
          :latency => latency.to_i,
          :bandwidth => bandwidth.to_i,
          :overhead => overhead.to_i
        }
        puts "[#{@name}]: Can connect to #{entry.to} through #{entry.interface} with latency #{latency}, bandwidth #{bandwidth}."
        @tactic_solver.update data

      else
        puts "[#{@name}]: Cannot connect to #{entry.to} through #{entry.interface}."

      end
    else
      puts "[#{@name}]: Tactic does not support interface #{entry.interface}"
    end
  end

  def print_error description
      puts "ERROR [#{@name}]: #{description}"
  end
end
