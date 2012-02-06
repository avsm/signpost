#!/usr/bin/env bash

echo "Remove modules.."
sudo modprobe -r openvswitch_mod
sudo modprobe -r brcompat_mod
sudo modprobe -r bridge

echo "Loading appropriate modules..."
sudo insmod /root/openvswitch/datapath/linux/openvswitch_mod.ko
sudo insmod /root/openvswitch/datapath/linux/brcompat_mod.ko

if [ ! -e /root/openvswitch/ovsdb.conf ]; then
    sudo ovsdb-tool create  /root/openvswitch/ovsdb.conf  /root/openvswitch/vswitchd/vswitch.ovsschema
fi

sudo ovsdb-server /root/openvswitch/ovsdb.conf --remote=punix:/var/run/ovsdb-server --detach --monitor 
sudo ovs-vswitchd unix:/var/run/ovsdb-server --detach --monitor

echo "setting the parameters..."
sudo ovs-vsctl --db=unix:/var/run/ovsdb-server init
sudo ovs-vsctl --db=unix:/var/run/ovsdb-server add-br br0
#sudo ovs-vsctl --db=unix:/var/run/ovsdb-server add-port br0 eth2
sudo ovs-vsctl --db=unix:/var/run/ovsdb-server add-port br0 eth0
sudo ovs-vsctl --db=unix:/var/run/ovsdb-server set-controller br0 tcp:127.0.0.1:6633
sudo ovs-vsctl --db=unix:/var/run/ovsdb-server set-fail-mode br0 standalone

sudo ifconfig br0 up
sudo dhclient br0

sudo ifconfig eth0 0.0.0.0
#sudo ifconfig eth2 0.0.0.0


