#!/usr/bin/env python

import ldns
import logging

def run_test(resolver, logger, test_opt):
    # create dns packet
    resolver.set_dnssec(True)
    res = resolver.prepare_query_pkt(""+test_opt["domain"], ldns.LDNS_RR_TYPE_SOA,
            ldns.LDNS_RR_CLASS_IN, 0)

    res_code = res.pop(0)
    if (res_code != ldns.LDNS_STATUS_OK):
        logger.warn("Failed to create dns request")
        return

    pkt = res.pop(0)
    pkt.set_rd(True)
    pkt.set_aa(True)

    pkt.push_rr(ldns.LDNS_SECTION_ADDITIONAL,
            ldns.ldns_rr.new_frm_str("st 3600 IN TXT hello_world!!!") )

    #generate new DSA key

    key = ldns.ldns_key.new_frm_fp(open("Ksp.+003+03490.private"))
    pkt.push_rr(ldns.LDNS_SECTION_ADDITIONAL,
            key.key_to_rr())
    logger.warn(pkt)

    # send request
    res = resolver.send_pkt(pkt)

    res_code = res.pop(0)
    if (res_code == ldns.LDNS_STATUS_OK):
        pkt = res.pop(0)
        logger.warn(pkt)
    else:
        logger.warn("name lookup failed!")

    resolver.set_dnssec(False)
