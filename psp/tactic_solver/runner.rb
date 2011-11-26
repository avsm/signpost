require 'tactic_solver'

puts "\n"
puts "##########################################"
puts "# Welcome to:                            #"
puts "#                                        #"
puts "#        TACTIC SOLVER 2000 TURBO        #"
puts "#                                        #"
puts "# Please go easy on the coffee!          #"
puts "##########################################"
puts "\n"

class RunHelper
  def self.get_input
    print "> "
    gets.strip.chomp
  end

  def self.happy_exclamation
    expressions = ["Jolly good", "Aye captain", "Way to go", 
                   "Fabulous", "Splendid", "Fantastic", "Good job"]
    "#{expressions[rand(expressions.size).to_i]}!"
  end

  def self.print_help
      puts <<-EOF
The program supports the following commands:


1. ad | ud    : adds or updates a device

   Requires the following parameters:
     Device id : System wide unique id
     Interface type : eth | bluetooth | ...
     Interface id: eth0 | eth1 | ...
     Address: Address the machine has under interface id.

   Example: ad ranger eth eth0 1.2.3.4

   ! Not implemented


2. exit       : terminates the program


3. nodes | n  : prints a list of known nodes


4. devices |d : lists all devices known in the system
  
   ! Not implemented


5. tick       : lightly tickle the data flow machinery to move things forward
EOF
  end

  def self.setup
    options = {}

    default_name = (0...8).map{65.+(rand(25)).chr}.join 
    puts "\nWhat should this node be called? (default: #{default_name})"
    name = RunHelper.get_input
    name = name == "" ? default_name : name
    options[:name] = name

    puts "Should #{name} be a server? [Y/N] (default: N)"
    server = (RunHelper.get_input =~ /y/i) == nil ? false : true
    options[:server] = server

    default_ip = "127.0.0.1"
    default_port = 56675
    if server then
      puts "What IP should we listen to (default: #{default_ip})"
      ip = RunHelper.get_input
      options[:ip] = ip == "" ? default_ip : ip

      puts "And port? (default: #{default_port})"
      port = RunHelper.get_input
      options[:port] = port == "" ? default_port : port.to_i

      puts "#{RunHelper.happy_exclamation} #{name} will be listening on #{options[:ip]}:#{options[:port]}"
    else
      puts "What IP should we contact the master on (default: #{default_ip})"
      ip = RunHelper.get_input
      options[:ip] = ip == "" ? default_ip : ip

      puts "And port? (default: #{default_port})"
      port = RunHelper.get_input
      options[:port] = port == "" ? default_port : port.to_i

      puts "#{RunHelper.happy_exclamation} We will contact the master on #{options[:ip]}:#{options[:port]}"
    end
    puts "\n\n"

    return options
  end
end

tactic_solver = TacticSolver.new RunHelper.setup
tactic_solver.setup_and_run

input = RunHelper.get_input
while not(input =~ /exit/i)
  case input
  when /foo/
    puts "bar"

  when /nodes/
    tactic_solver.tick
    puts "Nodes:"
    tactic_solver.nodes.each_pair do |k,v|
      puts "\t#{v[1]} : #{v[0]}"
    end

  when /(ad|ud) ([\w\d]*) ([\w\d]*) ([\w\d]*) ([\w\.\:]*)/
    id = $2
    interface_type = $3
    interface_id = $4
    address = $5
    tactic_solver.update_device id, interface_type, interface_id, address

  when /ad1/
    puts "Adding movember"
    id = "movember"
    interface_type = "eth"
    interface_id = "eth0"
    address = "12.0.143.20"
    tactic_solver.update_device id, interface_type, interface_id, address

  when /tick/
    tactic_solver.tick

  else
    RunHelper.print_help

  end
  input = RunHelper.get_input
end
# Important to shut it down when done, so the tactic daemons are killed
tactic_solver.shutdown

puts "\n\n"
puts "##########################################"
puts "#                                        #"
puts "# Good bye                               #"
puts "#                                        #"
puts "##########################################"
