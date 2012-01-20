#!/usr/bin/env bash 

loc_port=80

screen -dmS iperf_tcp sudo iperf -s -p $loc_port
screen -dmS iperf_udp sudo iperf -s -u -p $loc_port
screen -dmS pttcp echo need to see how I run this
ssh -i ~/.ssh/id_rsa -L 5001:localhost:5001 -L  6000:localhost:6000   -L  6001:localhost:6001  -L  6002:localhost:6002  -L  6003:localhost:6003  -L  6004:localhost:6004 cr409@chicane
