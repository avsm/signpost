#!/bin/bash

echo $common_name > clients
echo $trusted_ip >> clients
echo $ifconfig_pool_local_ip >> clients
echo $ifconfig_pool_remote_ip >> clients
exit 0

