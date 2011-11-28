require 'rubygems'
require 'bud'
require 'lib/tactic_protocol'
require 'lib/tactic'
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
    scratch :new_device, [:client_id, :interface_type, :interface_id] => [:address] # For adding devices locally
    table :devices, [:client_id, :interface_type, :interface_id] => [:address]
    table :links, [:from, :to, :strategy, :interface] => [:latency, :bandwidth, :overhead, :time_evaluated]
  end

  bloom :devices do
    # Another node wants to know about the devices we know about
    temp :device_request <= request_device_info.payloads
    serve_device_info <~ (device_request*devices).pairs do |req, dev|
      [req[0], dev]
    end

    # There is a potentially change to the list of devices
    # If the device is different from the info we already have,
    # then we update our device table
    temp :potentially_new_device_infos <= serve_device_info.payloads
    temp :new_device_info <= potentially_new_device_infos {|d|
      # We want to see if the device info differs from what we currently have
      d unless devices.exists? {|old_device| old_device == d }
    }
    devices <+- new_device_info

    # Tell all other nodes about the new device
    serve_device_info <~ (nodes*new_device).pairs do |node, device|
      [node.host, device]
    end
  end

  ###############################
  # Tactics #####################
  ###############################
  include TacticProtocol
  state do
    table :tactics, [:host] => [:name]
    channel :push_link
  end

  bloom :tactic_setup do
    tactics <= tactic_signup.payloads
  end

  bloom :tactize do
    # When there is a new device, send it to the tactic testers
    eval_tactic_request <~ (tactics*new_device_info).pairs do |t,nd|
      [t.host, nd]
    end

    temp :new_local_results <= tactic_evaluation_result.payloads
    push_link <~ (nodes*new_local_results).pairs do |n, r|
      # We get the results from the tactic solver in the following format
      # STRATEGY, NAME, ADDRESS, INTERFACE, LATENCY, BANDWIDTH, OVERHEAD
      strategy = r[0]
      name = r[1]
      address = r[2]
      interface = r[3]
      latency = r[4]
      bandwidth = r[5]
      overhead = r[6]
      evaluated = Time.now.to_i

      # The link table format is:
      # FROM, TO, STRATEGY, INTERFACE, LATENCY, BANDWIDTH, OVERHEAD,
      # TIME_EVALUATED
      result = [@name, address, strategy, interface, latency, bandwidth, overhead, evaluated]
      [n.host, result]
    end

    links <+- push_link.payloads
  end

  ###############################
  # Bootstrap (setup) ###########
  ###############################
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

  ###############################
  # Good old ruby ###############
  ###############################
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
    # We need to have the tactic solver running
    # before we initiate the tactics, otherwise
    # the tactics can't register with the tactics solver.
    self.run_bg
    # Start the tactics engine
    start_tactics
  end

  def update_device device_id, interface_type, interface_id, address
    device_info = [device_id, interface_type, interface_id, address]
    self.async_do {
      new_device <+ [device_info]
    }
  end
  alias :add_device :update_device 

  def shutdown
    @tactics.each { |tactic| tactic.tear_down_tactic }
  end

  private
  def connect_to host
    [host, [ip_port, @name]]
  end

  def start_tactics
    @tactics = []
    # Find and initialize all tactics
    Dir.foreach("tactics") do |dir_name|
      @tactics << Tactic.new(dir_name, ip_port) if File.directory?("tactics/#{dir_name}") and !(dir_name =~ /\.{1,2}/)
    end
    @tactics.each do |tactic| 
      tactic.run_bg
    end
  end
end
