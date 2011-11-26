# Tactics

Tactics can be any kind of tactic that can connect two devices.
A tactic consists of the following files:

config.yml - describing the tactic
a_prober - some executable that checks if a tactic applies or not
an_actuator - a process that is called to setup a connection using the tactic
background_process - a background process required to evaluate tactics

## config.yml

The configuration file should follow the pattern:

  description: Human readable description
  prober: PROBING_EXECUTABLE
  actuator: ACTUATING_EXECUTABLE
  daemon:
    start: COMMAND_TO_START_DAEMON
    stop: COMMAND_TO_STOP_DAEMON
  supported_interfaces:
    - eth
    ...


## PROBING_EXECUTABLE

The probing executable will be called as:

  PROBING_EXECUTABLE interface to

Where:
  
* interface: is the type of interface being tested
* to: is the destination address

The executable is expected to return either:

  FAILURE

if the tactic doesn't apply

or

  SUCCESS LATENCY BANDWIDTH OVERHEAD

Where:

* Latency is the latency that can be expected
* Bandwidth is the estimated avilable bandwidht
* Overhead is the number of bytes that are added to data packets


## ACTUATING_EXECUTABLE

Is expected to setup a connection using the tactic.

It is called as

  ACTUATING_EXECUTABLE interface to

And should return:

  FAILURE

If the connection couldn't be established, or

  SUCCESS IP PORT

Where IP is the IP a client can use to connect to the tunnel, and PORT the
portnumber to be used.


## DAEMON

Each tactic can have a daemon process running. This daemon might be used to
perform all the work related to a tactic, or only to aid incoming probes.  
The two commands, damon start and daemon stop, should start and stop the daemon
respectively.

The tactic solver does not directly interact with the daemon in any way, except
starting and stopping it.


## SUPPORTED_INTERFACES

A list of the interface types supported by this tactic.
Could be ethernet, or bluetooth, or any other technology.
SHOULD BE DEFINED...
