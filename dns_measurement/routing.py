#!/usr/bin/env python

import os

# regenerate the os routing table in order to check the outgoing 
# interface
import radix

# get scapy classes in order to browse the os routing table
import scapy
import scapy.config
from scapy.config import conf
import scapy.route

# int to string ip conversion functions
# import socket
# from struct import pack
from IPy import IP

# get wireless interface details
from pythonwifi.iwlibs import Wireless, getNICnames

# arping for dest mac
import subprocess
import sys

class SP_routing:
    """ 
    A simple class to load the rouing table of the host and decide which 
    interface should be monitored
    """
    def __init__(self):
        self._radix = radix.Radix()
#        print conf.route

        for rr in conf.route.routes:
#            print rr
            addr = IP("%s/%s"%(IP(rr[0]), IP(rr[1])))
#            print addr.strNormal()
            rnode = self._radix.add(addr.strNormal())
            rnode.data["gw"] = rr[2]
            rnode.data["intf"] = rr[3]
#
#        for rnode in self._radix:
#            print "%s/%d -> %s"%(rnode.network, rnode.prefixlen, str(rnode.data))

    def get_gw_for_ip(self, ip):
        rnode = self._radix.search_best(ip)
        if (rnode):
            return rnode.data['gw']
        else:
            return None

    def get_intf_for_ip(self, ip):
        rnode = self._radix.search_best(ip)
        if (rnode):
             return rnode.data['intf']
        else:
            return None

    def _lookup_mac(self, ip):
        os.system("ping -c 1 %s > /dev/null"%(ip))
        cmd="arp -a %s"%(ip)
        p=subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
        output, errors = p.communicate()
        if output is not None :
            for i in output.split("\n"):
#                print i
                if ip in i:
                    for j in i.split():
                        if ":" in j:
                            return j
        return "11:11:11:11:11:11"

    def get_intf_details(self, ip):
        rnode = self._radix.search_best(ip)
        intf = rnode.data['intf'] 
        wifi = Wireless(intf)
        res = wifi.getEssid()
        if(type(res) is tuple):
            dst_mac = ""
            if(rnode.data['gw'] == "0.0.0.0"):
                dst_mac = self._lookup_mac(ip)
#                print "the ns %s has a mac %s"%(ip, dst_mac)
            else:
                dst_mac = self._lookup_mac(rnode.data['gw'])
#                print "the gw %s has a mac %s"%(rnode.ata['gw'], dst_mac)
            return dict( is_wireless = False, dst_mac = dst_mac,
                    intf = intf, essid = "", ns = ip )       
        else:  
            return dict(is_wireless=True, dst_mac = wifi.getAPaddr(),
                    intf = intf, essid = res, ns = ip )
