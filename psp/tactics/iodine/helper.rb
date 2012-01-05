class Iodine < EventMachine::Connection
  def initialize helper, data = {}
    @a_day = 24 * 60 * 60
    @_helper = helper
    @_data = data
  end

private
  def send data
    send_data "#{data}\n"
  end
end

class IodineClient < Iodine
  def post_init
    send "connect_me:#{@_data[:ip]}:#{@_data[:password]}"
  end
  
  def receive_data data
    data.split("\n").each do |d|
      @_helper.log "Received #{d}"
    end
  end

end

class IodineDaemon < Iodine
  def post_init
    send "status?"
  end
  
  def receive_data data
    data.split("\n").each do |d|
      if data =~ /status:starting/ then
        # Ping again for the status in about a second
        @_helper.provide_truth "iodine_running", false, 10, true
        EM.add_timer(1) do
          send "status?"
        end
      end

      if data =~ /status:error/ then
        @_helper.provide_truth "iodine_running", false, 300, true
        # Check again to see if iodined is still unavailable
        EM.add_timer(280) do
          send "status?"
        end
      end

      if data =~ /status:running/ then
        @_helper.provide_truth "iodine_running", true, @a_day, true
        # Check again to see if iodined is still running
        EM.add_timer(@a_day - 10) do
          send "status?"
        end

        send "password?"
        send "port?"
      end

      if data =~ /password:([[:graph:]]*)/ then
        @_helper.provide_truth "iodine_password", $1, @a_day, true
      end

      if data =~ /port:([[:graph:]]*)/ then
        @_helper.provide_truth "iodine_port", $1, @a_day, true
      end
    end
  end
end
