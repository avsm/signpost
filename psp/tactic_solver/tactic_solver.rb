require 'rubygems'
require 'bud'
require "lib/tactic"
require 'pp'

class TacticSolver
  include Bud

  state do
    table :path, [:from, :to, :cost] => [:next, :latency, :bandwidth, :overhead]
    table :link, [:from, :to, :strategy, :interface] => [:latency, :bandwidth, :overhead]

    table :shortest, [:from, :to] => [:cost, :next, :latency, :bandwidth, :overhead]
  end

  # recursive rules to define all paths from links
  bloom :make_paths do
    # base case: every link is a path
    path <= link do |c| 
      [c.from, c.to, link_cost(c), c.to, c.latency, c.bandwidth, c.overhead]
    end
    
    # inductive case: make path of length n+1 by connecting a link to a path of
    # length n
    path <= (link * path).pairs(:to => :from) do |l,p|
      [l.from, p.to, 
       link_cost(l) + p.cost,
       p.from, 
       l.latency + p.latency, 
       min(l.bandwidth, p.bandwidth), 
       l.overhead + p.overhead]
    end
  end
  
  bloom :find_shortest do
    # shortest <= path.argmin([path.from, path.to], path.cost)
  end

  def initialize options = {}
    start_tactics
    super options
  end

  def add_input interface, to
    @tactics.each { |tactic| tactic.input_to_evaluate interface, to }
  end

  def update data
    new_data = [
      [ip_port, 
       data[:client], 
       data[:strategy],
       data[:interface],
       data[:latency],
       data[:bandwidth],
       data[:overhead]]
    ]
    self.sync_do {
      link <+ new_data
    }
  end

  def shutdown
    @tactics.each { |tactic| tactic.tear_down_tactic }
  end

  private
  def link_cost l
      10 * l.latency + 1000 / l.bandwidth + 10 * l.overhead # Find a way to compute cost...
  end

  def start_tactics
    @tactics = []
    # Find and initialize all tactics
    Dir.foreach("tactics") do |dir_name|
      @tactics << Tactic.new(dir_name, self) if File.directory?("tactics/#{dir_name}") and !(dir_name =~ /\.{1,2}/)
    end
    @tactics.each do |tactic| 
      tactic.post_setup
    end
  end

  def min a, b
    a < b ? a : b
  end

  def max a, b
    a < b ? b : a
  end
end

tactic_solver = TacticSolver.new
tactic_solver.run_bg
tactic_solver

tactic_solver.add_input "eth", "localhost"
tactic_solver.add_input "bluetooth", "localhost"

# Add some dummy data:
tactic_solver.sync_do {
  tactic_solver.link <+- [["macbook", "smartphone", "direct_connection", "eth", 200, 2000, 0],
                         ["macbook", tactic_solver.ip_port, "direct_connection", "eth", 100, 30000, 0],
                         ["work", "macbook", "direct_connection", "eth", 200, 300, 0],
                         ["macbook", "homecomputer", "direct_connection", "eth", 100, 30000, 0],
                         ["macbook", "ipad", "ssh", "eth", 130, 250, 14]]
}

# What are our shortest paths now?
puts "\n\n----------------------------"
puts "\nCurrent, shortest paths (Can't be calculated due to bug :|):"
puts ":("
tactic_solver.shortest.sort.each {|t| puts t.inspect}
puts "\nLinks:"
tactic_solver.link.sort.each {|t| puts t.inspect}
puts "\nPaths:"
tactic_solver.path.sort.each {|t| puts t.inspect}

# Important to shut it down when done, so the tactic daemons are killed
tactic_solver.shutdown
