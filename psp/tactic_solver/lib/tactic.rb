require 'yaml'
require 'timeout'


class Tactic
  include Bud
  include TacticProtocol

  bootstrap do
    tactic_signup <~ [[@tactic_solver, [ip_port, @name]]]
  end

  bloom :evaluate_tactic do
    temp :devices_to_evaluate <= eval_tactic_request.payloads

    temp :ignore <= devices_to_evaluate {|d| evaluate_input d; []}
  end
  
  def initialize name, tactic_solver, options = {}
    puts "> initializing tactic: #{name}"
    @name = name
    @tactic_solver = tactic_solver
    setup_tactic
    super options
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

  def evaluate_input data
    Thread.new(data, self) do |entry, tactic|
      begin
        Timeout::timeout(@timeout) do
          name = entry[0]
          interface = entry[1]
          address = entry[3]
          if @supported_interfaces.include?(interface) then
            puts "[#{@name}]: Evaluating possibility of connecting to #{address} through #{interface}"
            result = `tactics/#{@name}/#{@prober} #{interface} #{address}`
            if (result =~ /SUCCESS ([\d]*) ([\d]*) ([\d]*)/) != nil
              latency = $1
              bandwidth = $2
              overhead = $3
              puts "[#{@name}]: Can connect to #{address} through #{interface} with " \
                  + "latency #{latency}, bandwidth #{bandwidth}."

              # Returns values that can be sent back to the tactic solver
              result = [@name, name, address, interface, latency, bandwidth, overhead]
              self.async_do { self.tactic_evaluation_result <~ [[@tactic_solver, result]]}
              
            else
              puts "[#{@name}]: Cannot connect to #{address} through #{interface}."

            end # end if
          else
            puts "[#{@name}]: Tactic does not support interface #{interface}"
          end # end if

        end # end timeout

      rescue Timeout::Error
        print_error "Timed out when attempting to connect to #{address} through #{interface}."

      rescue e
        print_error "Failed when trying to conenct to #{address}: #{e}"

      end
    end
  end

  def print_error description
      puts "ERROR [#{@name}]: #{description}"
  end
end
