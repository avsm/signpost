require 'rubygems'
require 'bud'
require "lib/tactic"
require 'pp'

class TacticSolver
  include Bud

  ###############################
  # Signposts ###################
  ###############################
  state do
    channel :connect # For connecting to other nodes
    channel :node_discovery # For broadcasting nodes you know about
    table :nodes, [:host] => [:name]
  end
  
  # Handle setting up connections between signposts
  bloom :connections do
    # Information about new nodes from peers, must be dealt with
    temp :potentially_unknown_nodes <= node_discovery.payloads
    with :nodes_to_connect_to <= potentially_unknown_nodes {|c| 
      # Unseen nodes are nodes that we haven't seen before (excluding the
      # current node itself)
      c unless nodes.exists? {|n| n.host == c[0]}
    }, begin
      # We want to connect to nodes we haven't seen before
      nodes <+ nodes_to_connect_to
      connect <~ nodes_to_connect_to {|n| connect_to n[0]}
    end

    # -------------------------

    # Information about nodes trying to connect directly
    temp :connections <= connect.payloads

    temp :unseen_nodes <= connections do |c|
      # Unseen nodes are nodes that we haven't seen before (excluding the
      # current node itself)
      c unless nodes.exists? {|n| n.host == c[0]}
    end
    
    # Add nodes we don't yet know to our set of nodes
    nodes <+ unseen_nodes

    # Also, in order to allow a fully connected signpost graph,
    # inform the new nodes about other nodes we know about
    node_discovery <~ (connections*nodes).pairs do |new_node, existing_node|
      [new_node[0], existing_node]
    end
  end

  ###############################
  # Devices #####################
  ###############################
  state do
    channel :request_device_info
    channel :serve_device_info
    table :devices, [:client_id, :interface_type, :interface_id] => [:address]
    table :link, [:from, :to, :strategy, :interface] => [:latency, :bandwidth, :overhead, :time_evaluated]
  end

  bloom :devices do
    temp :device_request <= request_device_info.payloads
    serve_device_info <~ (device_request*devices).pairs do |req, dev|
      [req[0], dev]
    end
    temp :potentially_new_device_infos <= serve_device_info.payloads
    with :new_device_info <= potentially_new_device_infos {|d|
      # We want to see if the device info differs from what we currently have
      d unless devices.exists?(d)
    }, begin
      stdio <~ [["Got devices that need changing: #{new_device_info.inspected}"]]
      devices <+- new_device_info
    end
  end

  # Connect to the main tactic solver to get started.
  bootstrap do
    unless @runs_server then
      server = "#{@server_ip}:#{@server_port}"
      # Connect to the main machine
      connect <~ [connect_to server] # Connect to the network
      request_device_info <~ [connect_to server] # Request information about devices
    else
      nodes <= [[ip_port, @name]]
    end
  end

  def initialize options = {}
    @server_ip = options[:ip]
    @server_port = options[:port]

    @runs_server = options.delete(:server)

    # We don't want a client listening to the server IP and PORT!
    unless @runs_server then
      options.delete(:ip)
      options.delete(:port)
    end

    @run_mode = options.delete(:run)
    @name = options.delete(:name)

    super options
  end

  def setup_and_run
    # Start the tactics engine
    start_tactics
    # Now start the tactic_solver itself
    if @run_mode == :foreground then
      self.run_fg
    else
      self.run_bg
    end
  end

  def update_device device_id, interface_type, interface_id, address
    self.sync_do {
      self.serve_device_info <~ self.nodes {|node|
        [node.host, [device_id, interface_type, interface_id, address]]
      }
    }
    # Maybe add should do something else...
    # @tactics.each { |tactic| tactic.input_to_evaluate interface, to }
  end
  alias :add_device :update_device 

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
      mcast <~ new_data
    }
  end

  def shutdown
    @tactics.each { |tactic| tactic.tear_down_tactic }
  end

  private
  def connect_to host
    [host, [ip_port, @name]]
  end

  def handle_multicast_for what, data, &block
    recipient, payload = data
    # puts "Handling multicast. Looking for #{what}. Got payload:"
    if payload[0] == what then
      yield payload[1]
    else
      []
    end
  end

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
