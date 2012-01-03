module TacticSolver
  # Channel between objects
  #
  # Delegate methods:
  # new_channel:: Called when a connection to another signpost has been setup.
  #               Parameter:
  #               * The communication channel instance
  #
  # channel_closed:: Called when the channel has been termianted
  #                  by the remote signpost.
  #                  Parameter:
  #                  * The channel object 
  #
  # receive:: Called when data has been received
  #           Parameters:
  #           * The channel that received the data
  #           * The data received
  class CommsChannel < EventMachine::Connection
    def initialize delegate
      @_delegate = delegate
      super
    end

    def terminate_channel
      close_connection_after_writing
    end

    def send data
      send_data "#{data.to_json}\n"
    end

    def receive_data data
      data.split("\n").each do |d|
        begin
          e = JSON.parse(d)
          if e["hi_i_am"] then
            @_name = e["hi_i_am"]
            @_port = e["port"]
            data = {"nice_to_meet_you_i_am" => @_delegate.name, "port" => @_delegate.listen_port}
            send data
            @_delegate.new_channel self

          elsif e["nice_to_meet_you_i_am"] then
            @_name = e["nice_to_meet_you_i_am"]
            @_port = e["port"]
            # TODO: Move to CommsChannelServer init
            @_delegate.new_channel self

          else
            @_delegate.receive self, e

          end
        rescue JSON::ParserError
          $stderr.puts "Couldn't parse the input"
        end
      end
    end

    def unbind
      @_delegate.channel_closed
    end

    def ip_port
      port, ip = Socket.unpack_sockaddr_in(get_peername)
      [ip, @_port]
    end

    def name
      # TODO: This should return the device id returned by the SSL handshake.
      @_name
    end
  end

  # Handles incoming connections from other signposts.
  class CommsChannelServer < CommsChannel
    def initialize delegate
      super delegate
    end
  end
  
  # Sets up outgoing connections to other signposts.
  class CommsChannelClient < CommsChannel
    def post_init
      # Say hi and stuff
      data = {"hi_i_am" => @_delegate.name, "port" => @_delegate.listen_port}
      send data
      # start_tls(:private_key_file => '/tmp/server.key', :cert_chain_file => '/tmp/server.crt', :verify_peer => false)
    end
  end

  # The communication centre deals with the communication between signposts
  # withing the same signpost domain.
  #
  # All signposts are themselves responsible for distributing their own truths
  # to other signposts.
  class CommunicationCentre
    def initialize solver, signpost_domain
      @_solver = solver
      @_domain = signpost_domain
      @_channels = []
      @_name = "server"
      @_listen_port = 8987

      setup_comms_server
      find_signpost_from_dns
    end

    # --------------------------------------------------
    # CommsChannel Delegate methods
    # --------------------------------------------------

    def new_channel channel
      @_channels << channel

      # Ask the channel for it's list of connections
      data = {"action" => "list_of_signposts"}
      channel.send data

      # Ask the other signpost for its truths
      data = {"action" => "gimme_truths"}
      channel.send data
    end

    def channel_closed channel
      puts "TODO: Channel to #{channel.name} was terminated"
    end

    def receive channel, data
      # puts "Received from #{channel.name}:"
      # pp data
      perform_action_for_remote_signpost channel, data["action"] if data["action"]
      connect_to_signposts data["signposts"] if data["signposts"]
      handle_new_truths data["truths"] if data["truths"]
    end

    def distribute_truths truths
      data = {"truths" => truths}
      @_channels.each do |channel|
        channel.send data
      end
    end

    def name
      @_name
    end

    def listen_port
      @_listen_port
    end

  private
    def perform_action_for_remote_signpost channel, action
      case action
      when "list_of_signposts"
        data = {"signposts" => @_channels.map {|c| 
          ip, port = c.ip_port
          {"name" => c.name, "ip" => ip, "port" => port}}
        }
        channel.send data

      when "gimme_truths"
        # return all the truths we currently hold
        # to the other channel.
        truths = @_solver.exportable_truths
        data = {"truths" => truths}
        channel.send data

      end
    end

    def connect_to_signposts signposts
      signposts.each do |signpost|
        unless signpost["name"] == @_name then
          unless @_channels.index {|c| c.name == signpost["name"]} then
            connect_to_signpost signpost["ip"], signpost["port"]
          end
        end
      end
    end

    def handle_new_truths truths
      truths.each {|truth| @_solver.add_external_truth truth}
    end

    def setup_comms_server
      port = 8987
      orig_port = port
      running = false
      while !running do
        begin
          EventMachine::start_server("0.0.0.0", port, CommsChannelServer, self)
          running = true
          puts "Running with comms agent on port #{port}"
        rescue
          puts "Not possible on port #{port}"
          port = port + 1
        rescue
        end
      end
      # TODO: remove
      unless port == orig_port then
        @_name = "client-#{port - orig_port}"
        puts "Connecting to server"
        ip = "127.0.0.1"
        @_listen_port = port
        connect_to_signpost ip, orig_port
      end
    end

    def find_signpost_from_dns
      # Find the signpost as given by DNS and connect to it.
      # TODO: Find the remote channel through the tactic solver, and then
      # connect to it.
      ip = "127.0.0.1"
      port = 8987
      # connect_to_signpost ip, port
    end

    def connect_to_signpost ip, port = 8987
      # TODO: Use tactic solver to get a connectable ip, or tunnel or whatever.
      puts "TODO: Use tactic solver to find a way to connect to #{ip}:#{port}"
      puts "Connecting to #{ip}:#{port}"
      EventMachine::connect(ip, port, CommsChannelClient, self)
    end
  end
end
