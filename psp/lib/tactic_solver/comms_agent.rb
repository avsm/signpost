require 'digest/sha1'

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
      @_delegate.channel_closed self
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
    def initialize solver, config, logger
      @_solver = solver
      @_domain = config.signpost_domain
      @_channels = []
      @_name = config.signpost_client
      @_listen_port = config.port
      @_listen_ip = config.ip
      @_logger = logger

      setup_comms_server
      find_signpost_from_dns
    end

    # --------------------------------------------------
    # CommsChannel Delegate methods
    # --------------------------------------------------

    def new_channel channel
      # We don't want a signpost connecting with itself
      unless channel.name == @_name then
        @_channels << channel
        @_logger.log "new_signpost_connection", channel.name

        # Ask the channel for it's list of connections
        data = {"action" => "list_of_signposts"}
        channel.send data
        @_logger.log "request_remote_signposts", channel.name

        # Ask the other signpost for its truths
        data = {"action" => "gimme_truths"}
        channel.send data
        @_logger.log "request_remote_truths", channel.name

      else
        channel.terminate_channel

      end
    end

    def channel_closed channel
      return if channel.name == @_name

      # Remove the channel from the channel array.
      @_channels = @_channels.select do |ch|
        ch.name != channel.name
      end

      # If we are not connected to any signposts anymore,
      # then try to reconnect to the signpost from DNS! We don't want to be
      # alone!
      find_signpost_from_dns if @_channels.size == 0

      @_logger.log "signpost_connection_closed", channel.name
    end

    def receive channel, data
      # We got some new fancy data. Send it to all the others as well!
      # As long as it is about resolving truths, or spreading truths
      if data["truths"] or data["resolve"] then
        broadcast data, channel.name
      end

      perform_action_for_remote_signpost channel, data["action"] if data["action"]
      connect_to_signposts data["signposts"] if data["signposts"]
      handle_new_truths channel, data["truths"] if data["truths"]
      resolve channel, data["resolve"] if data["resolve"]
    end

    def distribute_truths truths
      data = {"truths" => truths}
      @_channels.each do |channel|
        channel.send data
        # This is really spammy logging
        truths.each do |truth|
          # TODO: Only log part of the truth? Maybe not the truth value? What
          # if it is sensitive data?
          @_logger.log "send_truth", channel.name, *truth
        end
      end
    end

    def name
      @_name
    end

    def listen_port
      @_listen_port
    end

    def known_signposts
      @_channels.map {|c| c.name}
    end

    def remote_resolve what, user_info, signpost
      @_logger.log "resolve_truth_remotely", signpost, what, user_info

      # We broadcast instead! Woho!
      data = {"resolve" => {"what" => what, "user_info" => user_info, "signpost" => signpost}}
      broadcast data, name

      # # Get the channel for the signpost where the truth should be resolved
      # channel = (@_channels.select do |s|
      #   s.name == signpost
      # end).first
      # # Resolve the truth request by sending it to the signpost that
      # # should resolve it.
      # if channel then
      #   data = {"resolve" => {"what" => what, "user_info" => user_info}}
      #   channel.send data
      #   []
      # else
      #   puts "ERROR: Trying to resolve '#{what}' for #{user_info} on node #{signpost} that doesn't exist"
      # end

    end

  private
    def broadcast data, original_sender
      return unless should_broadcast? data

      # Get all channels, except the sender that gave us the data
      channels = (@_channels.select do |s|
        s.name != original_sender
      end)

      channels.each do |channel|
        channel.send data
      end
    end

    def should_broadcast? data
      key = Digest::SHA1.hexdigest(data.to_s)
      broadcast_cache[key] ? false : true
    end

    def about_to_broadcast data
      cache = broadcast_cache
      key = Digest::SHA1.hexdigest(data.to_s)
      cache[key] = Time.now.to_i
      @_broadcast_cache = cache
    end

    def broadcast_cache
      unless @_broadcast_cache then
        @_broadcast_cache = {}
        prune_broadcast_cache
      end
      @_broadcast_cache
    end

    def prune_broadcast_cache
      EM.add_timer(5) do
        now = Time.now.to_i
        @_broadcast_cache.delete_if do |key, timestamp|
          # Delete the entry if it is older than 10 seconds
          timestamp < now - 10
        end
        prune_broadcast_cache
      end
    end

    def perform_action_for_remote_signpost channel, action
      case action
      when "list_of_signposts"
        data = {"signposts" => @_channels.map {|c| 
          ip, port = c.ip_port
          {"name" => c.name, "ip" => ip, "port" => port}}
        }
        channel.send data
        @_logger.log "return_list_of_signposts", channel.name

      when "gimme_truths"
        # return all the truths we currently hold
        # to the other channel.
        truths = @_solver.exportable_truths
        unless truths.size == 0 then
          data = {"truths" => truths}
          channel.send data
        end
        @_logger.log "return_list_of_truths", channel.name

      end
    end

    def connect_to_signposts signposts
      # TODO: If there are any signposts I haven't heard about yet, then
      # I should distribute them to other signposts I know of, so we get a consistent view!
      signposts.each do |signpost|
        unless signpost["name"] == @_name then
          unless @_channels.index {|c| c.name == signpost["name"]} then
            connect_to_signpost signpost["ip"], signpost["port"]
            @_logger.log "initiate_connection_to_signpost", signpost["name"]

          end
        end
      end
    end

    def handle_new_truths channel, truths
      truths.each {|truth| @_solver.add_external_truth truth}
      truths.each do |truth|
        @_logger.log "adding_remote_truth", channel.name, *truth
      end
    end

    def resolve channel, query
      what = query["what"]
      user_info = query["user_info"]
      options = {:what => what, :solver => @_solver.ip_port, :user_info => user_info}

      Question.new options do |truths|
        # We don't really need to deal with the result.
        # It will automatically be sent to the other signposts
        # where it will be given to the tactic that needs it.
      end
      @_logger.log "resolve_for_remote", channel.name, what, user_info
    end

    def setup_comms_server
      begin
        EventMachine::start_server(@_listen_ip, @_listen_port, CommsChannelServer, self)
        puts "Running signpost #{@_name} listening on #{@_listen_ip}:#{@_listen_port}"
      rescue RuntimeError => e
        raise "#{@_name} cannot listen on #{@_listen_ip}:#{@_listen_port}: #{e}"
      end
    end

    def find_signpost_from_dns
      options = {
        :what => "signpost_for_client@#{@_name}", 
        :solver => @_solver.ip_port, 
        :user_info => "SETUP",
        :asker => "SETUP"
      }
      Question.new options do |res|
        # Use the first signpost we get, and try connecting to it
        truths = res.to_a
        if truths.size > 0 then
          domain, port = truths.first[4]
          connect_to_signpost domain, port

        else
          raise "Cannot find a signpost to connect to for #{@_domain}. Please ensure the DNS is setup correctly."
        end
      end
    end

    def connect_to_signpost domain, port = 8987
      # We don't want to connect to ourselves
      unless domain == @_name then
        # TODO: Use tactic solver to get a connectable ip, or tunnel or whatever.
        puts "TODO: Use tactic solver to find a way to connect to #{domain}:#{port}"
        puts "Connecting to #{domain}:#{port}"
        EventMachine::connect(domain, port, CommsChannelClient, self)
      end
    end
  end
end
