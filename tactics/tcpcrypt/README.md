Get the source from: 

    git clone git://github.com/sorbo/tcpcrypt.git

In order to compile on Ubuntu, you need the following dependencies

    sudo apt-get install libnfnetlink-dev libnetfilter-queue-dev libcap-dev

To compile

    cd tcpcrypt/user
    ./configure
    make

To run

    cd tcpcrypt/user
    sudo ./launch_tcpcryptd.sh

To verify that it is running:
In one window:

    sudo tcpdump -X -s0 host tcpcrypt.org

In another window:

    curl tcpcrypt.org

Inspect that the output is indeed encrypted.

Remember:
When running iperf or whatever mechanism to test TCPCrypt, make sure it does
evaluate TCP and not UDP :)
