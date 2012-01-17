#!/usr/bin/env bash
# Start iodined server

FORWARD_PORT=5353
DOMAIN=i.d2.signpo.st

sudo iodined -f -c -b $FORWARD_PORT -P iodine_test 10.0.0.1 $DOMAIN
