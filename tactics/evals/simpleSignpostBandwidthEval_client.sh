#!/bin/bash
#CONFIG PARAMETERERS
MAX_ATTEMPTS="100"
SERVER_DOMAIN=server.d2.signpo.st
LISTENING_PORT="6650"
IPERF_INTERVAL="1"
IPERF_DUTY_CYCLE="5"
currentIter=1
while [ $currentIter -le $MAX_ATTEMPTS ]
do
  echo "New connection: $currentIter"
  currentIter=$(( $currentIter + 1 ))
  iperf -c $SERVER_DOMAIN -p $LISTENING_PORT -t $IPERF_DUTY_CYCLE -i $IPERF_INTERVAL 
done
