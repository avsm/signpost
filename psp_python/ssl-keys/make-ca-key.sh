#!/usr/bin/env bash

echo "generating signing private key..."
openssl genrsa -des3 -out ca.key 4096

echo "generate ca public certificate..."
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt
# openssl req -new -x509 -days 3650 -key ca.key -out ca.crtopenssl \
#     req -new -x509 -days 3650 -key ca.key -out ca.crt

echo "remove password from private key"
openssl rsa -in ca.key -out ca.key.insecure
