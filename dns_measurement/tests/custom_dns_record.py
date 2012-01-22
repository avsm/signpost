#!/usr/bin/env python


import os
import ldns

def run_test(resolver, logger, test_opt):
  """ This test checks if a dns server can be reached directly or we have to use
  some local resolver"""

  res = resolver.prepare_query_pkt("test.unbound.signpo.st", 300,
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

