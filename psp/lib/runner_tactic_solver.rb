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

module RunHelper
  def self.get_input
    gets.strip.chomp
  end

  def self.print_help
    puts <<-EOF
TacticSolver help

To exit type 'exit'

To run the tactic solver, type in something of the form

I want (a|to) WHAT (in)to WHERE [through port PORT]

Example:
  
  I want a connection to localhost
  I want to ssh into test.probsteide.com through port 22
  I want a connection to 127.0.0.1 through port 80

Shortcuts:

  c1: shortcut for "I want a connection to localhost"
  c2: shortcut for "I want a connection to localhost through port 8080"
  c3: shortcut for "I want to ssh to nf-test109.cl.cam.ac.uk through port 22"
EOF
  end
end

tactic_solver = TacticSolver::Solver.new
tactic_solver.setup_and_run

input = RunHelper.get_input
while not(input =~ /exit/i)
  case input
  when /I want (a|to) ([\w\d]*) (in)?to ([\w\d\.\-\_\:\@]*)( through port ([\d]*))?/
    puts "Something worked out"
    what = $2
    to = $4
    port = $6
    tactic_solver.resolve what, to, port.to_i

  when /c1/
    tactic_solver.resolve "connection", "localhost"

  when /c2/
    tactic_solver.resolve "connection", "localhost", 8080

  when /c3/
    tactic_solver.resolve "ssh", "nf-test109.cl.cam.ac.uk", 22

  when /I want (a|to) ([\.^ ]*) (in)?to ([\.^ ]*)( through port ([\d]*))?/
    puts "Something worked out"

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
