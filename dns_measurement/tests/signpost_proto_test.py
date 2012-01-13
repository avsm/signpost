#!/usr/bin/env python

import ldns
import logging

def run_test(resolver, logger):
    # create dns packet
    resolver.set_dnssec(True)
    res = resolver.prepare_query_pkt("signpo.st", ldns.LDNS_RR_TYPE_A,
            ldns.LDNS_RR_CLASS_IN, 0)

    res_code = res.pop(0)
    if (res_code != ldns.LDNS_STATUS_OK):
        logger.warn("Failed to create dns request")
        return

    pkt = res.pop(0)

    txt = ldns.ldns_rr_new_frm_type(ldns.LDNS_RR_TYPE_TXT)
    # data = ldns.ldns_rdf()
    data = ldns.ldns_rdf_new_frm_str(ldns.LDNS_RR_TYPE_TXT, "hello world!!")
    # data.set_size(len("hello world!!"))
    txt.push_rdf(data)
    print "Passed pushing info"
    pkt.push_rr(ldns.LDNS_SECTION_ANY, txt)

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
