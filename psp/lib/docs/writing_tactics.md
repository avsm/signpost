Writing tactics requires a somewhat different mindset from traditional
procedural programming. Instead of arguments to a function call, a tactic
specifies the data it needs to evaluate its tactic as *truth-needs*.
The *truth-needs* might be satisfied in any order, or not at all if there is no
tactic that can provide the truth, or all the ones that do fail.

# Definition

Each tactic lives in a subfolder of the tactic folder.
The subfolder must contain a config.yml file specifying what kinds of truths
(resource) the tactic provides, along with what static truth requirements the
tactic has. The configuration should also specify a unique tactic name, a human
readable description and the name of the tactic exectuable. 
The folder should also contain the tactic executable along with any other kind
of supporting files needed.

## Configuration

The following is a Cambridge inspired sample configuration showcasing some of the configuration
options:

    name: sample
    description: Illustrates how to configure tactics
    provides:
      - sample_(this|that)@Local(:[\d]*)?
      - gowns_to_be_(s)?worn@([[:graph:]]*)
    requires:
      - port_from_year_Port@Local:2222
      - suitable_gowns@Destination
      - formal_hall_at@Domain:3215
      - Resource@Local:2534
    executable: sample_executable.rb

The **provides** section is a list of truth types provided by the tactic. The
truth types are interpreted as regular expressions and matched against the
truth needs of clients and other tactics.

Capitalized words in the *provides* and *requires* section carry special meanings:

### The following are available in both the provides and requires sections

- **Local** is substituted with the name of the node the tactic is executed on.
  On a node Alpha, the sample_this resource will therefore only match sample_this@Alpha
  truth requests.


### The following are available exclusively in the requires section

The following assumes a request for gowns_to_be_worn@Darwin:20 on node Alpha.

- **Domain** is replaced with the domain in the truth request. A request for the truth formal_hall_at@Darwin:3215 would be issued.
- **Destination** is substituted with a combination of the Domain and Port.
  A truth request for suitable_gowns@Darwin:20 would be issued.
- **Port** is replaced with the port number in the truth request. A request for the
  truth port_from_year_20@Alpha:2222 would be issued.
- **Resource** is replaced with the truth requested. A request for the truth
  gowns_to_be_worn@Alpha:2534 would be issued.

## Communication with Tactic

The tactic solver communicates through STDIO with the tactics. STDERR is also
intercepted and piped into an error log (currently printed in the user shell).

All communication takes the form of JSON objects.

### Communication to the tactic

Truths are sent to the tactic using the following syntax:

    {"truths": [
        {
          "what":TRUTH_NAME,
          "source": THE_SOURCE_OF_THE_TRUTH,
          "value": TRUTH_VALUE
         }
      ]
    }

### Communication from the tactic

The tactic can return new truths using the syntax:

    {"provide_truths": [
        {
          "what": TRUTH_NAME, # i.e. tcp_in@node:12314
          "ttl": TTL, # in seconds, 0 = no-cache
          "value": VALUE,
          "global": BOOLEAN # whether other users can see this truth
        }
      ]
    }

Requests for additional truths:

    {"need_truths": [
        {
          "resource":RESOURCE_NAME, # i.e. tcp_in
          # optional combination of:
          "domain": DOMAIN, # domain for which truth should hold
          "port": PORT, # used in combination with the domain, if provided
          "destination": DESTINATION, # replaces domain and port if provided
          "holder: HOLDER # Which signpost node the truth should be evaluated at. Not yet implemented.
        }
      ]
    }

If only the port is provided, the same domain is used as in the orignal
request. If only a domain is provided, the domain is used without a port.
The destination parameter, if provided should take the form DOMAIN:PORT.

## Default parameters

The following parameters are provided by default to all tactics, if requested
or not:

- **what**: the full name of what is requested. i.e. tcp_in@remote_host:2341
- **port**: the port of the request. i.e. 2341 for tcp_in@remote_host_2341
- **domain**: the domain part of the full request. i.e. remote_host for
  tcp_in@remote_host:2341
- **destination**: full domain port combo. Same as domain if no port is
provided.
- **resource**: only the truth name itself. i.e. tcp_in for
tcp_in@remote_host:2341
- **client**: information about the client requesting the truth

# Helper
To make it simpler to write tactics, there is a helper class provided for ruby.

The following is a example of it's use:


    #! /usr/bin/ruby

    require 'rubygems'
    require 'bundler/setup'

    # includes the helper file
    require 'tactic_solver/tactic_helper'

    # create a new tactic helper. The tactic helper will deal with
    # the communication with the tactic solver
    tactic = tactichelper.new

    # you declare blocks of code that should get
    # executed whenever a set of required truths have been
    # provided. The following block has no truth requirements
    tactic.when do |helper, truths|
      # run at start.
      # at this point we have access to:
      # - what (the full resource destination combo)
      # - resource (the resource name)
      # - domain
      # - port
      # - destination
      #
      # The values are accessed as:
      # truths[THING][:value]
      # and the source can be gotten as:
      # truths[THING][:source]
    end

    # the following block is executed when both "tcp_in@l:200"
    # and "tcp_out@l:200" have been provided.
    # note that these truths will either have to have been requested
    # in the config.yml or in another block that can be scheduled to
    # run.
    tactic.when "tcp_in@l:200", "tcp_out@l:200" do |helper, truths|
      # request more truths
      helper.need_truth "my_truth", {:domain => "l"}
      helper.when "my_truth@l" do |h,t|
        # access the truth as t["my_truth@l"][:value]
      end
      # provide a new truth for the service provided by the tactic
      helper.provide_truth TRUTH_NAME, VALUE, TTL

      # tell the tactic solver that it can terminate this
      # tactic instance.
      helper.terminate_tactic
    end

    # we need to initialize the tactic, otherwise nothing will ever happen
    tactic.run
