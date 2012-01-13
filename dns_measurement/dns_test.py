#!/usr/bin/env python

import os
import time
import logging
import socket

import ldns
import glob
import sys
import threading

import pcapy

# this is really ugly, but useful also
running = True

def load_test(resolver, logger, test_opt):
    # for each script in folder test, load the code and run run_test function
    for test in test_opt["tests"]:
        print "running test %s"%(test)
       
       # if module is noty loaded, load it
        if not test in sys.modules:
            __import__(test)
        
        mymodule = sys.modules[test]
        test_log = logger.getChild(test)
        mymodule.run_test(resolver, test_log)
        time.sleep(10)

def capture_packets( intf, directory):
#    print "starting packet capture at %s from fevice %s"%(directory, intf)
    rdr = pcapy.open_live(intf, 2500, 1, 1000)

    dmp = rdr.dump_open(directory+"/trace.pcap")

    rdr.setfilter("udp")
    global running 
    while running:
        try:
            data = rdr.next()
            print "packet captured"
            dmp.dump(data[0], data[1])
        except socket.timeout:
            continue

    

def run_test(ns, measurement_id, test_opt):
    # define the folder name to store the results
    measurement_id_str = "%s/%s-%s-%ld"%(test_opt["data_dir"], 
            measurement_id["ns"], measurement_id["dst_mac"].replace(":", ""), 
            long(time.time()))
    if(measurement_id["is_wireless"]):
        measurement_id_str += measurement_id["essid"]    
    print measurement_id_str

    # create folder to store experiment results
    try:
        os.mkdir(measurement_id_str)
    except OSError:
        print "Folder exists"

    # save the log to file
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger(measurement_id_str)
    print "found %d handler"%(len(logger.handlers))
   
    #setup logging for the system
    if(len(logger.handlers) > 0) :
        logger.handlers[0].stream.close()
        logger.removeHandler(logger.handlers[0])
    
    file_handler = logging.FileHandler(measurement_id_str + "/measurement.log")
    file_handler.setLevel(logging.DEBUG)
    formatter = logging.Formatter("%(asctime)s %(filename)s, %(lineno)d: %(message)s")
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    
    # setup pcap capture mechanism
    

    # create a tmp file that resemple a resolv.conf file with only a single name server
    os.system("echo nameserver %s > %s/tmp.resolv.conf"%(measurement_id["ns"],
            measurement_id_str))
    resolver = ldns.ldns_resolver.new_frm_file("%s/tmp.resolv.conf"%(measurement_id_str))

    # remove resolv.conf file
    os.unlink("%s/tmp.resolv.conf"%(measurement_id_str))
    th1 = threading.Thread(target = load_test, args = (resolver, logger,
        test_opt))
    th2 = threading.Thread(target = capture_packets, 
            args = (measurement_id["intf"], measurement_id_str))

    global running
    running = True
    th1.start()
    th2.start()   
    th1.join()
    print "load_test finished"
    running = False
    th2.join()
    print "capture_packets finished"

