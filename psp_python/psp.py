#!/usr/bin/env python

from twisted.internet import glib2reactor
glib2reactor.install()

from twisted.internet import reactor, ssl
from twisted.web import server, resource, http
from twisted.web.error import Error
from twisted.internet.protocol import Factory, Protocol
from signpost_auth import HTTPSVerifyingContextFactory
import gobject, server_discovery
import json, logging, signpost_server
import signal, sys, mdns

def verifyCallback(connection, x509, errnum, errdepth, ok):
    if not ok:
        print('invalid cert from subject:' + x509.get_subject())
        return False
    else:
        print("Certs are fine")
        return True

# in order to use ssl use the following code
#  curl --key ssl-keys/laptop.key.insecure  --key-type PEM --cert ssl-keys/laptop.crt --cacert ssl-keys/ca.crt -k --data 'content={"port":8080,"ip":["10.10.0.3"]}' htt2:8080/v1/register  -vvv

def main():
    #init logger
    logger = logging.getLogger('psp')
    hdlr = logging.FileHandler('psp.log')
    strm_out = logging.StreamHandler(sys.__stdout__)
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    hdlr.setFormatter(formatter)
    strm_out.setFormatter(formatter)
    logger.addHandler(hdlr) 
    logger.addHandler(strm_out) 
    logger.setLevel(logging.INFO) 

    mdns_client = mdns.Mdns_client('laptop', 'haris.sp', 8080, logger)

    #init web server 
    site = server.Site(signpost_server.Singpost_server(logger))

    # run method in thread
    reactor.suggestThreadPoolSize(30)
    factory = Factory()
    reactor.listenSSL(8080, site, HTTPSVerifyingContextFactory()) #myContextFactory)
    mdns_client.setup_mdns()
    
    #service discovery module
    discovery = server_discovery.Server_discovery(logger)
    discovery.service_update() #initial discovery to fetch entries
    gobject.timeout_add(30000, discovery.service_update)
    
    # run the loop
    gobject.threads_init()
    gobject.MainLoop().run() 
 
if __name__ == "__main__":
    main()

