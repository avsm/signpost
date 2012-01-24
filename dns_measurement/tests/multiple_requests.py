#!/usr/bin/env python

import ldns
import logging

def run_test(resolver, logger, test_opt):
    # create dns packet
    resolver.set_dnssec(True)

    res = resolver.prepare_query_pkt(test_opt["domain"], ldns.LDNS_RR_TYPE_MX,
            ldns.LDNS_RR_CLASS_IN, 0)

    res_code = res.pop(0)
    if (res_code != ldns.LDNS_STATUS_OK):
        logger.warn("Failed to create dns request")
        return

    pkt = res.pop(0)
    pkt.set_rd(True)
    pkt.set_aa(True)

    pkt.push_rr(ldns.LDNS_SECTION_QUESTION,
         ldns.ldns_rr.new_question_frm_str("narseo.%s IN A"%(test_opt["domain"])))

    logger.warn(pkt)

    # send request
    res = resolver.send_pkt(pkt)

    res_code = res.pop(0)
    if (res_code == ldns.LDNS_STATUS_OK):
        logger.warn(res.pop(0))
    else:
        logger.warn("name lookup failed!")

    resolver.set_dnssec(False)
