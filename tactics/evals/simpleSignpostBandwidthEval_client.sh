#!/bin/bash
#CONFIG PARAMETERERS
function usage {
  #TODO
  echo "$0 -n <signpost name>"
  echo "-n domain or ip address of the iperf server"
  echo
  echo "Will write output to $NSDCONF"
  exit 1
}


MAX_ATTEMPTS="10"
LISTENING_PORT="6650"
IPERF_INTERVAL="1"
IPERF_DUTY_CYCLE="5"


echo "Server: $1 @ $2"
currentIter=1
SERVER_DOMAIN=$1
LISTENING_PORT=$2
while [ $currentIter -le $MAX_ATTEMPTS ]
do
  echo "New connection: $currentIter"
  currentIter=$(( $currentIter + 1 ))
  iperf -c $SERVER_DOMAIN -p $LISTENING_PORT -t $IPERF_DUTY_CYCLE -i $IPERF_INTERVAL 
done
