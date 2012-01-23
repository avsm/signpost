#!/usr/bin/env python

import ldns
import logging
import subprocess
import time
from os import system
import sys

def run_test(resolver, logger, test_opt):
    # create dns packet

    ns = resolver.pop_nameserver()
    out_file = open("%s/iodine.log"%(test_opt["output_dir"]), "w")
#    res = system("/usr/sbin/iodine -P foo %s test.%s"%(ns, test_opt["domain"]))
    iodine_res = subprocess.call(["iodine", "-r", "-P","foo", str(ns),
        "test."+test_opt["domain"]], stderr=out_file, stdout=out_file)
    out_file.close()

    # iodine failed
    if (iodine_res != 0) :
        logger.warn("iodine init failed. returned %d"%(iodine_res))
        return

    #setup tcpdump to capture data through tcpdump
    tcpdump = subprocess.Popen(["tcpdump", "-i", "dns0", "-w", 
        "%s/iodine_trace.pcap"%(test_opt["output_dir"])])
       
    # run the latency test using the iodine
    print "running latency test..."
    out_file = open("%s/latency.log"%(test_opt["output_dir"]), "w")
    res = subprocess.call(["/bin/ping", "-c", "10", "10.0.0.1"],
            stdout=out_file, stderr=out_file)
    out_file.close()

    # testing throughput using iperf
#    print "running throughput test..."
    out_file = open("%s/throughput-individual.log"%(test_opt["output_dir"]), "w")
    res = subprocess.call(["/usr/bin/iperf", "-c", "10.0.0.1", "-u", "-r", "-i", "1",
        "-t", "30"], stdout=out_file, stderr=out_file)
    out_file.close()

    tcpdump.kill()
    system("killall iodine")

