#!/usr/bin/env bash

# This script should be called as
# iperf_test.sh <tunnel_name> <timestamp> <interface> <ip> <port> <dest_location> <pttcp_dir>

tunnel_name=$1
timestamp=$2
mon_intf=$3
loc=aws
loc_ip=$4
loc_port=$5
duration=60
dst_loc=$6
pttcp_dir=$7

# chec ig params are correct
if [ ! -e $dst_loc ]; then 
	echo destination location doesn\'t exists.
	exit
fi 

echo starting iperf session 
# measuring the bulk transfer
/usr/sbin/tcpdump -i $mon_intf -w $loc-iperf_tcp-$tunnel_name-$timestamp.pcap &
ping $loc_ip | tee $loc-ping_iperf_tcp-$tunnel_name-$timestamp.txt &

iperf -c $loc_ip -i 1 -t $duration -p $loc_port -d | tee $loc-iperf_tcp-$tunnel_name-$timestamp.txt &

sleep $duration;

echo "Meaurement finished";
killall ping;
killall tcpdump; 
killall iperf;

echo starting pttcp session
# copying dat to appropriate locations
cp $loc-iperf_tcp-$tunnel_name-$timestamp.pcap $dst_loc/
cp $loc-iperf_tcp-$tunnel_name-$timestamp.txt $dst_loc/
cp $loc-ping_iperf_tcp-$tunnel_name-$timestamp.txt $dst_loc/

# measuring with pttcp 
/usr/sbin/tcpdump -i $mon_intf -w $loc-pttcp-$tunnel_name-$timestamp.pcap &
ping $loc_ip | tee $loc-ping_pttcp-$tunnel_name-$timestamp.txt &

$pttcp_dir/pttcp -c $loc_ip --interpage pareto 25 2 \
  --objsize pareto 12288 1.2 -B 6000 -N 30	| tee $loc-pttcp-$tunnel_name-$timestamp.txt &

sleep $duration;

echo "Meaurement finished";
killall ping;
killall tcpdump; 
killall pttcp;

# copying dat to appropriate locations
cp $loc-pttcp-$tunnel_name-$timestamp.pcap $dst_loc/
cp $loc-pttcp-$tunnel_name-$timestamp.txt $dst_loc/
cp $loc-ping_pttcp-$tunnel_name-$timestamp.txt $dst_loc/


# measuring streaming options
echo starting streaming test;
/usr/sbin/tcpdump -i $mon_intf -w $loc-iperf_udp-$tunnel_name-$timestamp.pcap &
ping $loc_ip | tee $loc-ping_iperf_udp-$tunnel_name-$timestamp.txt &

# dvd quality
iperf -c $loc_ip -p $loc_port -b 5700K -i 1 -t $duration | tee $loc-iperf_udp-$tunnel_name-$timestamp.txt &

sleep $duration;

echo "Meaurement finished";
killall ping;
killall tcpdump; 
killall iperf;

# copying dat to appropriate locations
cp $loc-iperf_udp-$tunnel_name-$timestamp.pcap $dst_loc/
cp $loc-iperf_udp-$tunnel_name-$timestamp.txt $dst_loc/
cp $loc-ping_iperf_udp-$tunnel_name-$timestamp.txt $dst_loc/
