#!/usr/bin/env bash

# Start ptunnel server

PASSWORD="ptunnel_eval_password"
echo
echo "****************"
echo "Starting ptunnel."
echo "Password is: $PASSWORD"
echo "****************"
echo
echo
sudo ptunnel -x $PASSWORD
