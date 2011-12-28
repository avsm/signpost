
SIGNPOST NSS plugin
-------------------------------

This code has been developed in order to intercept user name requests and push them 
to the personal signpost server. The code creates an nss plugin that translates name 
resolutions, web service requests. 

Build and install
-------------------------------

The code is has full integration with the autotools packagin system. In order to build
the conde you need the external libraries of curl (http://curl.haxx.se/libcurl/c/) and 
the janson json parsing library for c (http://www.digip.org/jansson/). In order the
right package system, you need to run the command in cli.

sudo apt-get install libjansson4 libjansson-dev libcurl libcurl-dev

In order to compile the code of the project you need to run the following commands:
./bootstrap.sh
./configure
make all install

Once the library has been install you need to configure the nss system in order to use the
signpost library. In order to achieve that, edit the file /etc/nsswitch.conf and register
signpost as the only service for host lookup. 

In order to setup the personal signpost to serve http request, users must start the 
runner_solver.rb, in order to run a solver daemon, and the runner_http_server.rb, in order
to run the http daemon thread.

