#!/usr/bin/env bash

#CONFIG PARAMETERERS
function usage {
  #TODO
  echo "$0 -n <signpost domain> -p <server port>"
  echo "-n domain or ip address of the iperf server"
  echo
  echo "Will write output to $NSDCONF"
  exit 1
}

#Define outputFileName
#Get tunnel description
tunnel=$3
ping_output="ping_client_"$tunnel".ping"
iperf_output="iperf_client_"$tunnel".iprf"
tcpdump_output="tdmp_client_"$tunnel".pcap"

#Run tcpdump on interface
tcpdump -w $tcpdump_output - i $4

echo "TUNNEL: $tunnel" >> $ping_output
echo "$(date +%Y%m%d%H%M%S) >> $ping_output
echo "Remote: $1" >> $ping_output
echo "TUNNEL: $tunnel" >> $iperf_output
echo "$(date +%Y%m%d%H%M%S) >> $iperf_output
echo "Remote: $1" >> $ipef_output


echo "Output ping file: $ping_output"
echo "Output iperf file: $iperf_output"

#Execution parameters
MAX_ATTEMPTS="5"
LISTENING_PORT="6650"
IPERF_INTERVAL="1"
IPERF_DUTY_CYCLE="5"
PING_MAX=($IPERF_DUTY_CYCLE / $IPERF_INTERVAL)
echo "IPERF DURATION: $IPERF_DUTY_CYCLE"
echo "IPERF INTERVAL: $IPERF_INTERVAL"
echo "PING_AMOUNT_REQUESTS: $PING_MAX"

echo "Server: $1 @ $2"
currentIter=1
SERVER_DOMAIN=$1
LISTENING_PORT=$2
while [ $currentIter -le $MAX_ATTEMPTS ]
do
  #This can be considered as for how long we want a test on a given link
  echo "New connection: $currentIter"
  currentIter=$(( $currentIter + 1 ))
  iperf -c $SERVER_DOMAIN -p $LISTENING_PORT -t $IPERF_DUTY_CYCLE -i $IPERF_INTERVAL | tee $iperf_output &
  ping -i $IPERF_INTERVAL -c $PING_MAX $SERVER_DOMAIN | tee $ping_output &
  wait
done
killall tcpdump
killall iperf
killall ping
