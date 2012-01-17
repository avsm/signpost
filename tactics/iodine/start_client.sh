#!/usr/bin/env bash
# Start iodined server
DOMAIN=i.d2.signpo.st

echo
echo "****************"
echo "Once the tunnel is setup, the following IP's should be setup:"
echo "  Server: 10.0.0.1"
echo "  Client: 10.0.0.2"
echo
echo "If there are other clients, then restart the system so you get consistent performance"
echo
echo "!!!!!!!!"
echo "It will ask you for your password so it can start iodine with root privileges"
echo "!!!!!!!!"
echo "****************"
echo
echo
echo

sudo iodine -f -P iodine_test $DOMAIN
