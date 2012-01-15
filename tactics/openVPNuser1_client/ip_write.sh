#!/bin/bash

echo $common_name > clients
echo $trusted_ip >> clients
echo $ifconfig_local >> clients
echo $ifconfig_remote >> clients
echo $ifconfig_pool_remote_ip >> clients

exit 0
