#!/bin/bash
#CONFIG PARAMETERERS
function usage {
  #TODO
  echo "$0 -p <listening port>"
  echo "-n domain or ip address of the iperf server"
  echo
  echo "Will write output to $NSDCONF"
  exit 1
}

MAX_ATTEMPTS="100"
SERVER_DOMAIN=server.d2.signpo.st
#LISTENING_PORT="6650"
IPERF_INTERVAL="1"
IPERF_DUTY_CYCLE="5"
currentIter=1
LISTENING_PORT=$1


echo "SignpostServer on port $LISTENING_PORT"
iperf -s -p $LISTENING_PORT -i $IPERF_INTERVAL