# This is a helper class that takes care receiving the data needed before
# executing code, etc.

require 'rubygems'
require 'eventmachine'
require 'lib/tactic_solver/tactic_helpers'

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

class CommunicationManager < EventMachine::Connection
  def initialize delegate
    @_delegate = delegate
    super

    @_delegate.manager = self
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
        $stderr.puts "ERROR: Tactic script couldn't parse its input"
      end
    end
  end

  # When the remote end closes the connection
  def unbind
    EventMachine::stop_event_loop
  end
  
end

class TacticHelper
  def initialize
    @_todos = []
    @_data = {}
    @_manager = nil
    @_ready_to_consider_processing_blocks = false
  end

  # ---------------------------------------
  # API methods for client
  # ---------------------------------------
  
  def when *requirements, &block
    @_todos << {:requirements => requirements.map{|r| r.to_sym}, :block => block, :req_versions => {}}
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
    need = add_option need, :signpost, options

    needs = {:need_truths => [need]}
    @_manager.relay_data needs
  end

  def observe_truth what, options = {}
    observe = {:what => what}
    observe = add_option observe, :domain, options
    observe = add_option observe, :port, options
    observe = add_option observe, :destination, options
    observe = add_option observe, :signpost, options

    for_observation = {:observe => [observe]}
    @_manager.relay_data for_observation
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

  def recycle_tactic
    # Reset to original state
    @_data = {}
    set_pending_tactic_state
    
    # Reset the data versions of the user provided execution blocks, so that we
    # do get execution happening, even for "old" data.
    @_todos.each do |todo|
      todo[:req_versions] = {}
    end

    # Tell the tactics engine that we are ready to be used again
    msg = {:recycle=> true}
    @_manager.relay_data msg
  end

  def run
    socket_name = ARGV[0]
    EventMachine::run do
      EventMachine::connect_unix_domain(socket_name, CommunicationManager, self)
    end
  end

  # ---------------------------------------
  # Delegate methods
  # ---------------------------------------

  def handle_input input
    deal_with_input input
    execute_user_blocks if @_ready_to_consider_processing_blocks
  end

  def manager= manager
    @_manager = manager
  end

  # ---------------------------------------

private
  def set_pending_tactic_state
    @_pending = [
      :destination, 
      :port, 
      :domain, 
      :resource, 
      :user,
      :is_daemon,
      :what,
      :user,
      :node_name
    ]
    @_ready_to_consider_processing_blocks = true
    remove_existing_from_pending
  end

  def set_pending_daemon_state
    @_pending = [
      :is_daemon,
      :node_name
    ]
    @_ready_to_consider_processing_blocks = true
    remove_existing_from_pending
  end

  def remove_existing_from_pending
    @_data.each_key do |key|
      @_pending.delete(key.to_sym)
    end
  end

  def execute_user_blocks
    # Don't execute any custom code before all the prerects are dealt with
    return if @_pending.size > 0

    @_todos.each do |todo|
      all_reqs_satisfied = true
      should_execute_block = false
      todo[:requirements].each do |req|
        all_reqs_satisfied = false unless @_data[req]
      end

      if all_reqs_satisfied then
        # This is the first time we are executing the block.
        # Initialize the version numbers of the requirements.
        if todo[:req_versions].size == 0 then
          versions = {}
          todo[:requirements].each do |req|
            versions[req] = @_data[req][:version]
          end
          # Also add the node_name. This way, blocks with no explicit
          # requirements, only get executed one.
          versions[:node_name] = @_data[:node_name][:version]
          todo[:req_versions] = versions
          should_execute_block = true

        else
          # Check if any of the data items are a newer
          # version than what the block has previously been
          # executed with.
          todo[:req_versions].each_pair do |req, version|
            data_version = @_data[req][:version]
            if data_version > version then
              todo[:req_versions][req] = data_version
              should_execute_block = true
            end
          end

        end
      end

      # Execute the user block
      todo[:block].call(self, @_data) if should_execute_block
    end

  end

  def add_option to, what, from
    to[what] = from[what] if from[what]
    to
  end

  def deal_with_input data
    # We have received new truths
    if data['truths'] then
      received_truths = data['truths']
      received_truths.each do |truth|
        what = truth["what"]
        value = truth["value"]
        source = truth["source"]
        user = truth["user"]
        signpost = truth["signpost"]

        # If we are informed whether we are a daemon,
        # then we can set up our pending variables
        if what == "is_daemon" then
          if value == true then
            # We are a daemon
            set_pending_daemon_state
          else
            # We are a tactic
            set_pending_tactic_state
          end
        end

        data_to_store = {
          :what => what, 
          :value => value, 
          :source => source,
          :user => user,
          :version => 1,
          :signpost => signpost
        }

        short_form = what

        # Get the different parts from the data
        begin
          vars = TacticSolver::Helpers.magic_variables_from what
          data_to_store[:domain] = vars[:domain]
          data_to_store[:destination] = vars[:destination]
          data_to_store[:port] = vars[:port]

          # We deal with the truths just as their resource names, rather than
          # full resource@domain combos. Makes it easier to write tactics.
          short_form = vars[:resource]

        rescue TacticSolver::ResourceTypeException
          # Not a proper resource... ignore it
        end

        @_pending.delete(short_form.to_sym)

        # If this is a value that has been updated, then make sure we update
        # the version number
        prev_data = @_data[short_form]
        # We have previous data. Increase the version number of the new data we
        # are inserting to replace the previous version.
        data_to_store[:version] = prev_data[:version] + 1 if prev_data

        log "Received #{short_form} -> #{value} (version: #{data_to_store[:version]})"

        # This is a little nasty... we store tons of dupes, unless they all
        # reference the same object of course...
        @_data[short_form.to_sym] = data_to_store
        @_data[short_form.to_s] = data_to_store
        @_data[what.to_s] = data_to_store
      end
    end
  end
end
