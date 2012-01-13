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
    else:
        logger.warn("name lookup failed!")


def run_test(resolver, logger):
    # create dns packet
    simple_lookup(resolver, logger, "signpo.st", ldns.LDNS_RR_TYPE_SOA)
    simple_lookup(resolver, logger,"signpo.st", ldns.LDNS_RR_TYPE_NS)
    simple_lookup(resolver, logger,"haris.signpo.st", ldns.LDNS_RR_TYPE_A)
    simple_lookup(resolver, logger,"narseo.signpo.st", ldns.LDNS_RR_TYPE_A)
    simple_lookup(resolver, logger,"anil.signpo.st", ldns.LDNS_RR_TYPE_AAAA)
    simple_lookup(resolver, logger,"anil.signpo.st", ldns.LDNS_RR_TYPE_AAAA)
    simple_lookup(resolver, logger,"signpo.st", ldns.LDNS_RR_TYPE_MX)
    simple_lookup(resolver, logger,"_http._tcp.signpo.st", ldns.LDNS_RR_TYPE_SRV)
    simple_lookup(resolver, logger,"_http._tcp.signpo.st", ldns.LDNS_RR_TYPE_SRV)
    simple_lookup(resolver, logger,"andrius.signpo.st", ldns.LDNS_RR_TYPE_HINFO)
    simple_lookup(resolver, logger,"andrius.signpo.st", ldns.LDNS_RR_TYPE_LOC)
    simple_lookup(resolver, logger,"andrius.signpo.st", ldns.LDNS_RR_TYPE_APL)
