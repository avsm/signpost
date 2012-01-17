#!/usr/bin/env bash

# Start ptunnel client

echo "Usage: $0 <proxy_url> <interface>"
echo

PROXY=$1
INTERFACE=$2
PORT=5000
HOST="127.0.0.1"
PASSWORD="ptunnel_eval_password"

echo
echo "****************"
echo "Connecting to $PROXY"
echo "Local port $PORT is relaying to $HOST:$PORT"
echo "Packet capture on device $INTERFACE"
echo "Using password: $PASSWORD"
echo "****************"
echo
sudo ptunnel -c $INTERFACE -p $PROXY -lp $PORT -da $HOST -dp $PORT -x $PASSWORD
