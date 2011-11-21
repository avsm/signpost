#!/usr/bin/env bash

echo "generating key $1..."
openssl genrsa -des3 -outform PEM -out $1.key 4096

echo "generating certificate signing request..."
openssl req -new -key $1.key -out $1.csr

openssl x509 -req -days 365 -in $1.csr -CA ca.crt -CAkey ca.key \
    -set_serial 01 -out $1.crt

openssl rsa -in $1.key -out $1.key.insecure
