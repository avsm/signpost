#!/usr/bin/env bash

count=1;

dst_loc=/anfs/nos2/cr409/signpost_data/
mon_intf=eth4
loc=aws
loc_ip=t3.signpo.st
loc_port=5001
#loc_port=80
duration=60
dur_sleep=1800
#dur_sleep=1800
$pttcp_dir=/home/cr409/pttcp/

# chec ig params are correct
if [ ! -e $dst_loc ]; then 
	echo destination location doesn\'t exists.
	exit
fi 

while [ 1 ]; do 
  count=$(( $count + 1 ));
  echo "running test $count";

	echo starting iperf session 
	# measuring the bulk transfer
  /usr/sbin/tcpdump -i $mon_intf -w $loc-iperf_tcp-$count.pcap &
  ping $loc_ip | tee $loc-ping_iperf_tcp-$count.txt &

  iperf -c $loc_ip -i 1 -t $duration -p $loc_port -d | tee $loc-iperf_tcp-$count.txt &

  sleep $duration;

  echo "Meaurement finished";
  killall ping;
  killall tcpdump; 
	killall iperf;

	echo starting pttcp session
	# copying dat to appropriate locations
  cp $loc-iperf_tcp-$count.pcap $dst_loc/
  cp $loc-iperf_tcp-$count.txt $dst_loc/
  cp $loc-ping_iperf_tcp-$count.txt $dst_loc/

	# measuring with pttcp 
	/usr/sbin/tcpdump -i $mon_intf -w $loc-pttcp-$count.pcap &
  ping $loc_ip | tee $loc-ping_pttcp-$count.txt &

	$pttcp_dir/pttcp -c $loc_ip --interpage pareto 25 2 \
		--objsize pareto 12288 1.2 -B 6000 -N 30	| tee $loc-pttcp-$count.txt &

  sleep $duration;

  echo "Meaurement finished";
  killall ping;
  killall tcpdump; 
	killall pttcp;

	# copying dat to appropriate locations
  cp $loc-pttcp-$count.pcap $dst_loc/
  cp $loc-pttcp-$count.txt $dst_loc/
  cp $loc-ping_pttcp-$count.txt $dst_loc/


	# measuring streaming options
	echo starting streaming test;
	/usr/sbin/tcpdump -i $mon_intf -w $loc-iperf_udp-$count.pcap &
  ping $loc_ip | tee $loc-ping_iperf_udp-$count.txt &

	# dvd quality
	iperf -c $loc_ip -p $loc_port -b 5700K -i 1 -t $duration | tee $loc-iperf_udp-$count.txt &

  sleep $duration;

  echo "Meaurement finished";
  killall ping;
  killall tcpdump; 
	killall iperf;

	# copying dat to appropriate locations
  cp $loc-iperf_udp-$count.pcap $dst_loc/
  cp $loc-iperf_udp-$count.txt $dst_loc/
  cp $loc-ping_iperf_udp-$count.txt $dst_loc/

  sleep $dur_sleep;
done



