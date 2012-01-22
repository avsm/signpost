#!/usr/bin/env bash

# This script should be called as
# iperf_test.sh <tunnel_name> <timestamp> <interface> <ip> <port> <dest_location> <pttcp_dir>

tunnel_name=$1
timestamp=$2
mon_intf=$3
loc=home
loc_ip=$4
loc_port=$5
base_port=$6
duration=60
dst_loc=$7
pttcp_dir=$8
conn_num=10

# chec ig params are correct
if [ ! -e $dst_loc ]; then 
	echo destination location doesn\'t exists.
	exit
fi 

echo starting iperf session 
# measuring the bulk transfer
/usr/sbin/tcpdump -i $mon_intf -w $loc-iperf_tcp-$tunnel_name-$timestamp.pcap &
ping $loc_ip | tee $loc-ping_iperf_tcp-$tunnel_name-$timestamp.txt &

echo iperf -c $loc_ip -i 1 -t $duration -p $loc_port -d > test_output.txt 
iperf -c $loc_ip -i 1 -t $duration -p $loc_port -L $loc_port -d | tee $loc-iperf_tcp-$tunnel_name-$timestamp.txt &

sleep $duration;

echo "Meaurement finished";
killall ping;
killall tcpdump; 
killall iperf;

echo starting pttcp session
# copying dat to appropriate locations
mv $loc-iperf_tcp-$tunnel_name-$timestamp.pcap $dst_loc/
mv $loc-iperf_tcp-$tunnel_name-$timestamp.txt $dst_loc/
mv $loc-ping_iperf_tcp-$tunnel_name-$timestamp.txt $dst_loc/

# measuring with pttcp 
/usr/sbin/tcpdump -i $mon_intf -w $loc-pttcp-$tunnel_name-$timestamp.pcap &
ping $loc_ip | tee $loc-ping_pttcp-$tunnel_name-$timestamp.txt &

$pttcp_dir/pttcp -c $loc_ip --interpage pareto 25 2 -n $conn_num \
  --objsize pareto 12288 1.2 -B $base_port -N 11 | tee $loc-pttcp-$tunnel_name-$timestamp.txt &

sleep $duration;

echo "Meaurement finished";
killall ping;
killall tcpdump; 
killall pttcp;

# copying dat to appropriate locations
mv $loc-pttcp-$tunnel_name-$timestamp.pcap $dst_loc/
mv $loc-pttcp-$tunnel_name-$timestamp.txt $dst_loc/
mv $loc-ping_pttcp-$tunnel_name-$timestamp.txt $dst_loc/


# measuring streaming options
echo starting streaming test;
/usr/sbin/tcpdump -i $mon_intf -w $loc-iperf_udp-$tunnel_name-$timestamp.pcap &
ping $loc_ip | tee $loc-ping_iperf_udp-$tunnel_name-$timestamp.txt &

# dvd quality
iperf -c $loc_ip -p $loc_port -L $loc_port -b 5700K -i 1 -t $duration -d | tee $loc-iperf_udp-$tunnel_name-$timestamp.txt &

sleep $duration;

echo "Meaurement finished";
killall ping;
killall tcpdump; 
killall iperf;

# copying dat to appropriate locations
mv $loc-iperf_udp-$tunnel_name-$timestamp.pcap $dst_loc/
mv $loc-iperf_udp-$tunnel_name-$timestamp.txt $dst_loc/
mv $loc-ping_iperf_udp-$tunnel_name-$timestamp.txt $dst_loc/
