#!/usr/bin/env bash
# Start iodined server

set -e

function usage {
  echo "-d the domain that iodined listens to"
  echo 
  echo "-h : display this message"
  echo
  echo "Will setup an iodined server"
  exit 1
}

DOMAIN=i.d2.signpo.st
while getopts "n:" opt; do
  case $opt in
    d)
      DOMAIN="$OPTARG"
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

sudo iodine -f -P iodine_test $DOMAIN
