#!/usr/bin/env python

import ldns
import logging


def simple_lookup(resolver, logger, name, typ):
    
    res = resolver.prepare_query_pkt(name, typ,
            ldns.LDNS_RR_CLASS_IN, 0)
     
    res_code = res.pop(0)
    if (res_code != ldns.LDNS_STATUS_OK):
        logger.warn("Failed to create dns request")
        return

    pkt = res.pop(0)
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


def run_test(resolver, logger):
    # create dns packet
    resolver.set_dnssec(True)

    # set dnssec keys as anchors
    res = resolver.prepare_query_pkt("signpo.st", ldns.LDNS_RR_TYPE_DNSKEY,
            ldns.LDNS_RR_CLASS_IN, 0)
     
    res_code = res.pop(0)
    if (res_code != ldns.LDNS_STATUS_OK):
        logger.warn("Failed to create dns request")
        return

    pkt = res.pop(0)
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
    
    while keys.rr_count() > 0:
        rr = keys.pop_rr()
        print rr
        resolver.push_dnssec_anchor(rr)

    simple_lookup(resolver, logger, "signpo.st", ldns.LDNS_RR_TYPE_SOA)
    simple_lookup(resolver, logger,"signpo.st", ldns.LDNS_RR_TYPE_NS)
    simple_lookup(resolver, logger,"haris.signpo.st", ldns.LDNS_RR_TYPE_A)
    simple_lookup(resolver, logger,"narseo.signpo.st", ldns.LDNS_RR_TYPE_A)
    simple_lookup(resolver, logger,"anil.signpo.st", ldns.LDNS_RR_TYPE_AAAA)
    simple_lookup(resolver, logger,"anil.signpo.st", ldns.LDNS_RR_TYPE_AAAA)
    simple_lookup(resolver, logger,"signpo.st", ldns.LDNS_RR_TYPE_MX)
    
    simple_lookup(resolver, logger,"_http._tcp.signpo.st", ldns.LDNS_RR_TYPE_SRV)
    simple_lookup(resolver, logger,"andrius.signpo.st", ldns.LDNS_RR_TYPE_HINFO)
    simple_lookup(resolver, logger,"andrius.signpo.st", ldns.LDNS_RR_TYPE_LOC)
    simple_lookup(resolver, logger,"andrius.signpo.st", ldns.LDNS_RR_TYPE_APL)
    simple_lookup(resolver, logger,"faulty-dnssec.signpo.st",
            ldns.LDNS_RR_TYPE_A)
    resolver.set_dnssec(False)
