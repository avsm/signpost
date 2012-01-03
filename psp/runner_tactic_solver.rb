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

exit
  Terminates the program

(r|resolve) truth [signpost]
  resolves a truth either locally, or on a remote signpost if provided 

tactics 
  Lists all the tactics

truths
  Shows all the truths known in the system

user_info: 
  Set the user information passed along with requests.
  Usage:
    
    user_info INFO
            
subs
  Returns a list of all current truth subscribers/observers

running?
  Returns whether or not the EventMachine reactor is running

EOF
  end
end

user_info = "default_user_info"
resolver_name = "node_name"

tactic_solver = TacticSolver::Solver.new resolver_name

input = RunHelper.get_input
while not(input =~ /exit/i)
  case input
  when /(r|resolve) ([[:graph:]]*)( ([[:graph:]]*))?\Z/
    what = $2
    signpost = $4
    if signpost then
      puts "Should resolve #{what} on #{signpost}"
      tactic_solver.resolve what, user_info, signpost
    else
      puts "Should resolve #{what}"
      tactic_solver.resolve what, user_info
    end

  when /tactics\Z/
    pp tactic_solver.tactics.to_a

  when /(t|truths)\Z/
    pp tactic_solver.truths.to_a

  when /user_info ([[:graph:]]*)\Z/
    user_info = $1

  when /subs\Z/
    pp tactic_solver.truth_subscribers.to_a

  when /running\?\Z/
    if EventMachine::reactor_running? then
      puts "Reactor is running"
    else
      puts "Reactor is DOWN"
    end

  else
    RunHelper.print_help

  end
  input = RunHelper.get_input
end
# Important to shut it down when done, so the tactic daemons are killed
tactic_solver.stop

puts "\n\n"
puts "##########################################"
puts "#                                        #"
puts "# Good bye                               #"
puts "#                                        #"
puts "##########################################"
