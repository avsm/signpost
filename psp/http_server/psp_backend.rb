require 'http_server/psp_connection'
require 'pp'

module Thin
  module Backends
    # Backend to act as a TCP socket server.
    class PspServer < Base
      # Address and port on which the server is listening for connections.
      attr_accessor :host, :port

      def initialize(host, port, options)
        puts "this is the psp backend firing!!! yeah!!!!\n"
        @host = host
        @port = port
        super()
      end

      # Connect the server
      def connect
        puts "psp connect method called\n"
        @signature = EventMachine.start_server(@host, @port, PspConnection, &method(:initialize_connection))
      end

      # Stops the server
      def disconnect
        EventMachine.stop_server(@signature)
      end

      def to_s
        "#{@host}:#{@port}"
      end

      protected
      # Initialize a new connection to a client.
      def initialize_connection(connection)
        connection.backend = self
        connection.app = @server.app
        connection.comm_inactivity_timeout = @timeout
        connection.threaded = @threaded

        connection.start_tls(:private_key_file => 'ssl-keys/server.key.insecure', 
                                                  :cert_chain_file => 'ssl-keys/server.crt', 
                                                  :verify_peer => true)

        # We control the number of persistent connections by keeping
        # a count of the total one allowed yet.
        if @persistent_connection_count < @maximum_persistent_connections
          connection.can_persist!
          @persistent_connection_count += 1
        end

        @connections << connection
      end
    end
  end
end
