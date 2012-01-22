#!/usr/bin/env python

import os
import ldns

def run_test(resolver, logger, test_opt):
  """ This test checks if a dns server can be reached directly or we have to use
  some local resolver"""
  # create a tmp file that resemple a resolv.conf file with only a single name server
  os.system("echo nameserver 107.20.30.37 > tmp.resolv.conf")

  resolver = ldns.ldns_resolver.new_frm_file("tmp.resolv.conf")
  resolver.set_recursive(True)

  os.unlink("tmp.resolv.conf")

  res = resolver.prepare_query_pkt("test.signpo.st", ldns.LDNS_RR_TYPE_SOA,
    ldns.LDNS_RR_CLASS_IN, 0)
   
  res_code = res.pop(0)
  if (res_code != ldns.LDNS_STATUS_OK):
    logger.warn("Failed to create dns request")
    return

  pkt = res.pop(0)
  pkt.set_rd(True)
  pkt.set_aa(True)
  logger.warn(pkt)

  # send request
  res = resolver.send_pkt(pkt)

  res_code = res.pop(0)
  if (res_code == ldns.LDNS_STATUS_OK):
    pkt = res.pop(0)
    logger.warn(pkt)
  else:
    logger.warn("name lookup failed!")

