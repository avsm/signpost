#!/usr/bin/env python

import ldns
import logging


def simple_lookup(resolver, logger, name, typ, checking):
    
    res = resolver.prepare_query_pkt(name, typ,
            ldns.LDNS_RR_CLASS_IN, 0)
     
    res_code = res.pop(0)
    if (res_code != ldns.LDNS_STATUS_OK):
        logger.warn("Failed to create dns request")
        return

    pkt = res.pop(0)
    pkt.set_rd(True)
    pkt.set_aa(True)
    pkt.set_cd(checking)
    logger.warn(pkt)

    # send request
    res = resolver.send_pkt(pkt)

    res_code = res.pop(0)
    if (res_code == ldns.LDNS_STATUS_OK):
        pkt = res.pop(0)
        logger.warn(pkt)
        if( ldns.ldns_verify(
                pkt.rr_list_by_type(typ, ldns.LDNS_SECTION_ANSWER),
                pkt.rr_list_by_type(ldns.LDNS_RR_TYPE_RRSIG,
                    ldns.LDNS_SECTION_ANSWER),
                resolver.dnssec_anchors(),
                None) == ldns.LDNS_STATUS_OK):
            logger.warn("verification success")
        else:
            logger.warn("verification failed")
    else:
        logger.warn("name lookup failed!")


def run_test(resolver, logger, test_opt):
    # create dns packet
    resolver.set_dnssec(True)

    # set dnssec keys as anchors
    res = resolver.prepare_query_pkt(""+test_opt["domain"], ldns.LDNS_RR_TYPE_DNSKEY,
            ldns.LDNS_RR_CLASS_IN, 0)
     
    res_code = res.pop(0)
    if (res_code != ldns.LDNS_STATUS_OK):
        logger.warn("Failed to create dns request")
        return

    pkt = res.pop(0)
    pkt.set_rd(True)
    pkt.set_aa(True)
    pkt.set_cd(True)
    logger.warn(pkt)

    # send request
    res = resolver.send_pkt(pkt)

    res_code = res.pop(0)
    if (res_code == ldns.LDNS_STATUS_OK):
        pkt = res.pop(0)
        logger.warn(pkt)
    else:
        logger.warn("name lookup failed!")
    
    keys = pkt.rr_list_by_type(ldns.LDNS_RR_TYPE_DNSKEY, 
           ldns.LDNS_SECTION_ANSWER)
    if keys :
      while keys.rr_count() > 0:
          rr = keys.pop_rr()
          print rr
          resolver.push_dnssec_anchor(rr)

    for checking in [True, False]:
      simple_lookup(resolver, logger, test_opt["domain"], ldns.LDNS_RR_TYPE_SOA,
                    checking)
      simple_lookup(resolver, logger, test_opt["domain"], ldns.LDNS_RR_TYPE_NS,
                    checking)
      simple_lookup(resolver, logger, "haris."+test_opt["domain"], ldns.LDNS_RR_TYPE_A,
                    checking)
      simple_lookup(resolver, logger, "narseo."+test_opt["domain"], ldns.LDNS_RR_TYPE_A,
                      checking)
      simple_lookup(resolver, logger, "anil."+test_opt["domain"], ldns.LDNS_RR_TYPE_AAAA,
                      checking)
      simple_lookup(resolver, logger, "anil."+test_opt["domain"], ldns.LDNS_RR_TYPE_AAAA,
                    checking)
      simple_lookup(resolver, logger, test_opt["domain"], ldns.LDNS_RR_TYPE_MX,
                    checking)
    
      simple_lookup(resolver, logger,"_http._tcp."+test_opt["domain"], ldns.LDNS_RR_TYPE_SRV,
                    checking)
      simple_lookup(resolver, logger,"andrius."+test_opt["domain"], ldns.LDNS_RR_TYPE_HINFO,
                    checking)
      simple_lookup(resolver, logger,"andrius."+test_opt["domain"], ldns.LDNS_RR_TYPE_LOC,
                    checking)
      simple_lookup(resolver, logger,"andrius."+test_opt["domain"], ldns.LDNS_RR_TYPE_APL,
                    checking)
      simple_lookup(resolver, logger,"faulty."+test_opt["domain"],
            ldns.LDNS_RR_TYPE_A, checking)
      simple_lookup(resolver, logger,"nonexisting."+test_opt["domain"], ldns.LDNS_RR_TYPE_A,
                    checking)

    resolver.set_dnssec(False)
