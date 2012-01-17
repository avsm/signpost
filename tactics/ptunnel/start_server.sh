#!/usr/bin/env bash

# Start ptunnel server

echo "Usage: $0 <interface>"
echo

INTERFACE=$1

PASSWORD="ptunnel_eval_password"
echo
echo "****************"
echo "Starting ptunnel."
echo "Capturing packets on $INTERFACE"
echo "Password is: $PASSWORD"
echo "****************"
echo
echo
sudo ptunnel -c $INTERFACE -x $PASSWORD
