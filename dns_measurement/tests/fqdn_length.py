#!/usr/bin/env python

import ldns
import logging

def run_test(resolver, logger, test_opt):
    # create dns packet
    resolver.set_dnssec(True)

    domain = "unbound." +test_opt["domain"]

    pref = ""
    result = 0 
    while result == 0 :
        pref += ("a"*63)+"."
        logger.warn("sending query of length %d"%(len(pref+domain)))
        res = resolver.prepare_query_pkt(pref + domain, ldns.LDNS_RR_TYPE_A,
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

        result = res.pop(0)
        if (res_code == ldns.LDNS_STATUS_OK):
            logger.warn(res.pop(0))
        else:
            logger.warn("name lookup failed!")

    resolver.set_dnssec(False)
