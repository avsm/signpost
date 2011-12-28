Writing tactics requires a somewhat different mindset from traditional
procedural programming. Instead of arguments to a function call, a tactic
specifies the data it needs to evaluate its tactic as *truth-needs*.
The *truth-needs* might be satisfied in any order, or not at all if there is no
tactic that can provide the truth, or all the ones that do fail.

The tactic solver is the entity responsible for finding tactics to provide
truths. In practise that means that tactics themselves never interact.

# Definition

Each tactic lives in a subfolder of the tactics folder.
The subfolder must contain a config.yml file specifying what kinds of truths
(resource) the tactic provides, along with what static truth requirements the
tactic has. The configuration should also specify a unique tactic name, a human
readable description and the name of the tactic exectuable. 
The folder should also contain the tactic executable along with any other kind
of supporting files needed.

## Configuration

The following is a Cambridge inspired sample configuration showcasing some of the configuration options:

    name: sample_tactic
    description: Illustrates how to configure tactics
    provides:
      - sample_(this|that)@Local(:[\d]*)?
      - gowns_to_be_(s)?worn@([[:graph:]]*)
    requires:
      - port_from_year_Port@Local:2222
      - suitable_gowns@Destination
      - formal_hall_at@Domain:3215
      - Resource@Local:2534
    executable: sample_tactic_executable
    daemon: sample_daemon_executable

The executable listed as executable will be executed on demand to provide the truths
listed in the **provides** section. The daemon executable on the other hand
will only ever be executed once, when the tactic solver starts.
The daemon can itself express needs and provide truths, just like a tactic can.
The **provides** and **requires** sections only apply to the tactic executable,
and are ignored in the case of the daemon.

The **provides** section is a list of truth types provided by the tactic. The
truth types are interpreted as regular expressions and matched against the
truth needs of clients and other tactics.

Capitalized words in the *provides* and *requires* section carry special meanings:

### The following are available in both the provides and requires sections

- **Local** is substituted with the name of the node the tactic is executed on.
  On a node Alpha, the sample_this resource will therefore only match sample_this@Alpha(:[\d]*)?
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

## Tactic life cycle (aka. recycling for a sunstainable solver)

When a truth is needed that doesn't exist in the tactic solver's bag of truth,
the tactic solver executes tactics that are candidates for providing the truth.
Tactics are run as separate processes and have a substantial overhead on
startup. The tactic solver will therefore do its best to use an already started
tactic. This requires some cooperation from the tactics:

When a tactic has finished its execution, instead of terminating, it should
report to the tactic solver that it is recycling. When recycling, a tactic
should remove all state that it held from the previous invocation, and be in
the same state it was in when originally started.

A tactic can choose to remain active: never terminate or recycle. In that state
the tactic will receive updates for all truths it has expressed interests in,
and can therefore itself emit new truths to the tactic solvers in response to
other changing truths. 
A tactic that has remained active, will not receive requests to resolve new
truths. Instead a fresh tactic will be spawned, at great cost. It is therefore recommended that tactics do not remain active, but instead recycle as quickly as possible. The work that would normally have been performed by a tactic remaining active, can in most cases instead be given to the tactics daemon process (implemented shortly).

## Communication with Tactic

The tactic solver communicates with the tactics using unix sockets.
All communication takes the form of JSON objects.
The unix socket the tactic is supposed to use is passed as the first and only
argument to the tactic.

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

#### Providing truths

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


#### More truths

Requests for additional truths:

    {"need_truths": [
        {
          "resource":RESOURCE_NAME, # i.e. tcp_in
          # optional combination of:
          "domain": DOMAIN, # domain for which truth should hold
          "port": PORT, # used in combination with the domain, if provided
          "destination": DESTINATION, # replaces domain and port if provided
        }
      ]
    }

A tactic, or more often a tactic daemon, can also observe truths. Being an
observer will not cause a truth to be generated if it doesn't already exist,
but the observer will be informed when it is created or changed.

To become an observer, a tactic sends the following to the tactic solver:

    {"observe": [
        {
          "resource":RESOURCE_NAME, # i.e. tcp_in
          # optional combination of:
          "domain": DOMAIN, # domain for which truth should hold
          "port": PORT, # used in combination with the domain, if provided
          "destination": DESTINATION, # replaces domain and port if provided
        }
      ]
    }

The combinations of domain, port and destination have different effects if they
come from a tactic or a daemon:

If a truth need or observation request is issued by a:

- tactic, then if only the port is provided, the same domain is used as in the orignal
  request. If only a domain is provided, the domain is used without a port.
  The destination parameter, if provided should take the form DOMAIN:PORT.
- daemon, then only the parameters passed are used. If neither of domain, port,
  or destination are provided, the daemon will get passed all changed truths of
  that resource type.


#### Recycling

A tactic can tell the solver that it is ready to be recycled using the following
message:

    {"recycle":true}



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
    require 'lib/tactic_solver/tactic_helper'

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
      # The values are indexed by their resource name.
      # If you wanted to access the value of ip_for_domain@kle.io
      # you would call:
      # truths[:ip_for_domain][...]
      # To get the value itself, use:
      # truths[THING][:value]
      # the source can be gotten as:
      # truths[THING][:source]
      # and if you want to access the whole resource,
      # i.e. ip_for_domain@kle.io, call:
      # truths[:ip_for_domain][:what]
    end

    # the following block is executed when both "tcp_in@l:200"
    # and "tcp_out@l:200" have been provided.
    # note that these truths will either have to have been requested
    # in the config.yml or in another block that can be scheduled to
    # run.
    tactic.when :tcp_in, :tcp_out do |helper, truths|
      # request more truths
      helper.need_truth "my_truth", {:domain => "l"}

      # provide a new truth for the service provided by the tactic
      helper.provide_truth TRUTH_NAME, VALUE, TTL
    end

    # This block becomes executable when the truth requested above
    # becomes available.
    helper.when :my_truth do |h,t|
      # access the truth as t[:my_truth][:value]

      # tell the tactic solver that the tactic is ready to be reused.
      helper.recycle_tactic
    end

    # we need to initialize the tactic, otherwise nothing will ever happen
    tactic.run
