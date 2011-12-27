# This is a helper class that takes care receiving the data needed before
# executing code, etc.

require 'rubygems'
require 'eventmachine'
require 'pp'

$stdout.sync = true
$stderr.sync = true

gem "json"
begin
  require "json/ext"
rescue LoadError
  $stderr.puts "C version of json (fjson) could not be loaded, using pure ruby one"
  require "json/pure"
end

unless ARGV.size == 1 then
  puts "The tactic should be called with a unix socket for communication"
  exit 1
end
unix_socket = ARGV[0]

class CommunicationManager < EventMachine::Connection
  def initialize delegate
    @_delegate = delegate
    super

    @_delegate.manager = self
  end

  def stop_manager
    # For some reason the closing of the connection_after_write
    # seems to happen immediately, rathen than after write.
    # Therefore, delay the closing a little while.
    EM.add_timer(1) do
      self.close_connection_after_writing()
    end
  end

  def relay_data data
    send_data "#{data.to_json}\n"
  end

  def receive_data data
    data.split("\n").each do |d|
      begin
        e = JSON.parse(d)
        @_delegate.handle_input e
      rescue JSON::ParserError
        $stderr.puts "Couldn't parse the input"
      end
    end
  end

  def unbind
    EventMachine::stop_event_loop
  end
  
end

class TacticHelper
  def initialize
    @_todos = []
    @_data = {}
    @_manager = nil

    @_should_run = true
    @_pending = [:destination, :port, :domain, :resource, :user]
  end

  def when *requirements, &block
    @_todos << {:requirements => requirements.map{|r| r.to_sym}, :block => block}
  end

  def log msg
    logs = {:logs => [msg]}
    @_manager.relay_data logs
  end

  def need_truth what, options = {}
    need = {:what => what}
    need = add_option need, :domain, options
    need = add_option need, :port, options
    need = add_option need, :destination, options

    needs = {:need_truths => [need]}
    @_manager.relay_data needs
  end

  def provide_truth what, value, ttl = 0, global = false, options = {}
    truth = {
      :what => what,
      :ttl => ttl,
      :value => value,
      :global => global
    }
    new_truth = {:provide_truths => [truth.merge(options)]}
    @_manager.relay_data new_truth
  end

  def terminate
    @_should_run = false
    @_manager.stop_manager
  end

  def run
    socket_name = ARGV[0]
    EventMachine::run do
      EventMachine::connect_unix_domain(socket_name, CommunicationManager, self)
    end
  end

  def handle_input input
    deal_with_input input
    execute_user_blocks
  end

  def terminate_tactic
    @_should_run = false
    @_manager.stop_manager
  end

  def manager= manager
    @_manager = manager
  end

private
  def execute_user_blocks
    # Don't execute any custom code before all the prerects are dealt with
    return if @_pending.size > 0

    @_todos.each do |todo|
      break unless @_should_run

      all_reqs_satisfied = true
      todo[:requirements].each do |req|
        all_reqs_satisfied = false unless @_data[req]
      end

      # Execute the user block
      todo[:block].call(self, @_data) if all_reqs_satisfied
    end

  end

  def add_option to, what, from
    to[what] = from[what] if from[what]
    to
  end

  def deal_with_input data
    # Allow the tactic to terminate us
    @_should_run = false if data['terminate']

    # We have received new truths
    if data['truths'] then
      received_truths = data['truths']
      received_truths.each do |truth|
        what = truth['what']
        value = truth['value']
        source = truth['source']

        # We deal with the truths just as their resource names, rather than
        # full resource@domain combos. Makes it easier to write tactics.
        what =~ /([[:graph:]]*)@([[:graph:]]*)/
        short_form = $1 || what

        log "Received #{short_form} -> #{value}"
        @_pending.delete(short_form.to_sym)

        @_data[short_form.to_sym] = {:what => what, :value => value, :source => source}
        @_data[short_form.to_s] = {:what => what, :value => value, :source => source}

      end
    end

  end
end
