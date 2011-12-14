require 'lib/tactic_solver'

puts "\n"
puts "##########################################"
puts "# Welcome to:                            #"
puts "#                                        #"
puts "#        TACTIC SOLVER 2000 TURBO        #"
puts "#                                        #"
puts "# Please go easy on the coffee!          #"
puts "##########################################"
puts "\n"

module RunHelper
  def self.get_input
    gets.strip.chomp
  end

  def self.print_help
    puts <<-EOF
TacticSolver help

To exit type 'exit'

exit
  Terminates the program

tactics 
  Lists all the tactics

truths
  Shows all the truths known in the system

user_info: 
  Set the user information passed along with requests.
  Usage:
    
    user_info INFO
            

-------------------------

Supported calls:

  (r|resolve) truth

or 'free text' entries like:

I want (a|to) WHAT (in)to WHERE [through port PORT]

Example:
  
  I want a connection to localhost
  I want to ssh into test.probsteide.com through port 22
  I want a connection to 127.0.0.1 through port 80

Shortcuts:

  c1: shortcut for "I want a connection to localhost"
  c2: shortcut for "I want a connection to localhost through port 8080"
  c3: shortcut for "I want to ssh to nf-test109.cl.cam.ac.uk through port 22"
  c4: shortcut for "resolve tcp_in@localhost:8000"


EOF
  end
end

user_info = "default_user_info"
resolver_name = "node_name"

tactic_solver = TacticSolver::Solver.new resolver_name

input = RunHelper.get_input
while not(input =~ /exit/i)
  case input
  when /I want (a|to) ([\w\d]*) (in)?to ([\w\d\.\-\_\:\@]*)( through port ([\d]*))?/
    what = $2
    to = $4
    port = $6
    tactic_solver.resolve "#{what}@#{to}:#{port.to_i}", user_info

  when /c1\Z/
    tactic_solver.resolve "connection@#{resolver_name}", user_info

  when /c2\Z/
    tactic_solver.resolve "connection@#{resolver_name}:8080", user_info

  when /c3\Z/
    tactic_solver.resolve "ssh@nf-test109.cl.cam.ac.uk:22", user_info

  when /c4\Z/
    tactic_solver.resolve "tcp_in@#{resolver_name}:8000", user_info

  when /c5\Z/
    tactic_solver.resolve "tcp_out@#{resolver_name}:8000", user_info

  when /(r|resolve) ([[:graph:]]*)\Z/
    what = $2
    puts "Should resolve #{what}"
    tactic_solver.resolve what, user_info

  when /tactics\Z/
    pp tactic_solver.tactics.to_a

  when /(t|truths)\Z/
    pp tactic_solver.truths.to_a

  when /user_info ([[:graph:]]*)\Z/
    user_info = $1

  when /subs\Z/
    pp tactic_solver.truth_subscribers.to_a

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
