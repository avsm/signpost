#!/usr/bin/env bash
# Start iodined server

set -e

function usage {
  echo "-p forwarding port for DNS"
  echo "-d the domain that the iodine should listen to."
  echo "   if you use i, then you should have the following DNS recrods:"
  echo "      i NS ins"
  echo "      ins A <IP_OF_MACHINE>"
  echo 
  echo "-h : display this message"
  echo
  echo "Will setup an iodined server"
  exit 1
}

FORWARD_PORT=5353
DOMAIN=i.d2.signpo.st
while getopts "n:" opt; do
  case $opt in
    d)
      DOMAIN="$OPTARG"
      ;;
    p)
      FORWARD_PORT="$OPTARG"
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

sudo iodined -f -c -b $FORWARD_PORT -P iodine_test 10.0.0.1 $DOMAIN
