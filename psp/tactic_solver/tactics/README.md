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
background_process: BACKGROUND_PROCESS
supported_interfaces:
  - eth
  ...


## PROBING_EXECUTABLE

The probing executable will be called as:

  PROBING_EXECUTABLE interface from to

Where:
  
* interface: is the type of interface being tested
* from: is the source address
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

  ACTUATING_EXECUTABLE interface from to

And should return:

  FAILURE

If the connection couldn't be established, or

  SUCCESS IP PORT

Where IP is the IP a client can use to connect to the tunnel, and PORT the
portnumber to be used.


## BACKGROUND_PROCESS

A background process that is running on all signposts. It can be used to test
the availability of a tactic. The tactic solver never interacts directly with
this process.

If this process returns any output upon being started, the tactic solver we
take this as an indication of an error, and the tactic will not be executed.


## SUPPORTED_INTERFACES

A list of the interface types supported by this tactic.
Could be ethernet, or bluetooth, or any other technology.
SHOULD BE DEFINED...
