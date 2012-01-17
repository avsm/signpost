#!/usr/bin/env bash

# Start ptunnel client

PROXY = $1
PORT=5000
HOST="127.0.0.1"
PASSWORD="ptunnel_eval_password"

echo
echo "****************"
echo "Connecting to $PROXY"
echo "Local port $PORT is relaying to $HOST:$PORT"
echo "Using password: $PASSWORD"
echo "****************"
echo
sudo ptunnel -p $PROXY -lp $PORT -da $HOST -dp $PORT -x $PASSWORD
