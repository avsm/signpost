#!/usr/bin/env python

import os
import logging
import socket

import ldns
import glob
import sys
import threading

from time import time,sleep
import pcapy

# this is really ugly, but useful also
running = True

def load_test(resolver, logger, test_opt):
    # for each script in folder test, load the code and run run_test function
    for test in test_opt["tests"]:
        print "running test %s"%(test)

       # if module is not loaded, load it
        if not test in sys.modules:
            __import__(test)

        mymodule = sys.modules[test]
        test_log = logger.getChild(test)
        mymodule.run_test(resolver, test_log, test_opt)
        
        # give some time to pcap to save all files
        sleep(10)

def capture_packets(intf, directory):
    # listen on all devices
    rdr = pcapy.open_live("any", 2500, 1, 1000)

    # save file name 
    dmp = rdr.dump_open(directory+"/trace.pcap")

    # capture only dns traffic
    rdr.setfilter("udp port 53")
    global running 

    # start loop on the data
    while running:
        try:
            data = rdr.next()
            dmp.dump(data[0], data[1])
        except socket.timeout:
            continue

def run_test(ns, measurement_id, test_opt):
    # define the folder name to store the results
    measurement_id_str = "%s/%s-%d"%(test_opt["data_dir"], 
            measurement_id, time())
    print measurement_id_str
    test_opt["output_dir"] = measurement_id_str

    # create folder to store experiment results
    try:
        os.mkdir(measurement_id_str)
    except OSError:
        print "Folder exists"

    # save the log to file
    logging.basicConfig(filename= measurement_id_str + "/measurement.log", level=logging.DEBUG)
    logger = logging.getLogger(measurement_id_str)

    # create a tmp file that resemple a resolv.conf file with only a single name server
    os.system("echo nameserver %s > %s/tmp.resolv.conf"%(measurement_id,
            measurement_id_str))
    resolver = ldns.ldns_resolver.new_frm_file("%s/tmp.resolv.conf"%(measurement_id_str))
    resolver.set_recursive(True)

    # remove resolv.conf file
    os.unlink("%s/tmp.resolv.conf"%(measurement_id_str))
    
    # init the threads
    th1 = threading.Thread(target = load_test, args = (resolver, logger,
        test_opt))
    th2 = threading.Thread(target = capture_packets, 
            args = ("", measurement_id_str))

    # ugly hack to make the threads communicate ans signal the end of the tests
    global running
    running = True

    # let the running
    th1.start()
    th2.start()   
    th1.join()
    print "load_test finished"
    running = False
    th2.join()
    print "capture_packets finished"

