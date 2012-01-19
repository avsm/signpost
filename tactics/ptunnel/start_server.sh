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
echo "ptunnel password is: $PASSWORD"
echo "It might request you to type in your 'sudo' password next"
echo "****************"
echo
echo
sudo ptunnel -c $INTERFACE -x $PASSWORD
