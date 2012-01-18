Uses ICMP to tunnel traffic. Pretty neat.

Developer website: [http://www.cs.uit.no/~daniels/PingTunnel/](http://www.cs.uit.no/~daniels/PingTunnel/)

The following bandwidth measurements are given on the developers website:

    150 kb/s downstream and about 50 kb/s upstream are the currently measured maximas for one tunnel, but with tweaking this can be improved further

# To install

## MacOSX:

    brew install ptunnel

## Ubuntu

    sudo apt-get install ptunnel

### Troubleshooting

libpcap is a requirement for packet capturing. If things don't work, try:

    sudo apt-get install libpcap-dev
