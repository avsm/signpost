#! /usr/bin/env bash

set -e

num=`cat ../config.ml | grep signpost_number | awk '{print $4}'`
domain=`cat ../config.ml | grep domain | awk '{print $4}' | sed 's/"//g'`
sender="tester"
destination="$1"

request="$destination.$sender.d$num.$domain"

echo "Requesting $request"

dig @localhost -p 5354 "$request" A
