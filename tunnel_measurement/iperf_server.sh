#!/usr/bin/env bash 

loc_port=80

screen -dmS iperf_tcp sudo iperf -s -p $loc_port
screen -dmS iperf_udp sudo iperf -s -u -p $loc_port
screen -dmS pttcp echo need to see how I run this
