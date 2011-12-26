# This is a helper class that takes care receiving the data needed before
# executing code, etc.

require 'rubygems'

$stdout.sync = true
$stderr.sync = true

gem "json"
begin
  require "json/ext"
rescue LoadError
  $stderr.puts "C version of json (fjson) could not be loaded, using pure ruby one"
  require "json/pure"
end

class TacticHelper
  def initialize
    @_todos = []
    @_data = {}
  end

  def when *requirements, &block
    @_todos << {:requirements => requirements.map{|r| r.to_sym}, :block => block}
  end

  def log msg
    logs = {:logs => [msg]}
    $stdout.puts logs.to_json
  end

  def need_truth what, options = {}
    need = {:what => what}
    need = add_option need, :domain, options
    need = add_option need, :port, options
    need = add_option need, :destination, options

    needs = {:need_truths => [need]}
    $stdout.puts needs.to_json
  end

  def provide_truth what, value, ttl = 0, global = false, options = {}
    truth = {
      :what => what,
      :ttl => ttl,
      :value => value,
      :global => global
    }
    new_truth = {:provide_truths => [truth.merge(options)]}
    $stdout.puts new_truth.to_json
  end

  def terminate
    @_should_run = false
  end

  def run
    @_should_run = true
    @_pending = [:destination, :port, :domain, :resource, :user]

    while @_should_run do
      value = $stdin.readline("\n")

      begin
        data = JSON.parse(value)
        deal_with_input data

        execute_user_blocks

      rescue JSON::ParserError
        $stderr.puts "Couldn't parse the input"

      end
    end
  end

  def terminate_tactic
    @_should_run = false
  end

private
  def execute_user_blocks
    # Don't execute any custom code before all the prerects are dealt with
    return if @_pending.size > 0

    @_todos.each do |todo|
      all_reqs_satisfied = true
      todo[:requirements].each do |req|
        all_reqs_satisfied = false unless @_data[req]
      end

      # Execute the user block
      todo[:block].call(self, @_data) if all_reqs_satisfied
      exit 0 unless @_should_run
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
