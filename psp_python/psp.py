#!/usr/bin/env python

from twisted.internet import glib2reactor
glib2reactor.install()

from twisted.internet import reactor, ssl
from twisted.web import server, resource, http
from twisted.internet.protocol import Factory, Protocol
from twisted.web.error import Error
from OpenSSL.SSL import Context, TLSv1_METHOD, VERIFY_PEER, OP_NO_SSLv3
from OpenSSL.SSL import VERIFY_CLIENT_ONCE, VERIFY_FAIL_IF_NO_PEER_CERT
from OpenSSL.crypto import load_certificate, FILETYPE_PEM
from twisted.internet.ssl import ContextFactory

import signpost, gobject, server_discovery
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
class HTTPSVerifyingContextFactory(ContextFactory):
    def __init__(self):
        self.hostname = "localhost"

    isClient = True
    def getContext(self):
        ctx = Context(TLSv1_METHOD)
        store = ctx.get_cert_store()
        data = open("ssl-keys/ca.crt").read()
        x509 = load_certificate(FILETYPE_PEM, data)
        store.add_cert(x509)
        
        ctx.use_privatekey_file('ssl-keys/server.key.insecure', FILETYPE_PEM)
        ctx.use_certificate_file('ssl-keys/server.crt', FILETYPE_PEM)
        
        # throws an error if private and public key not match
        ctx.check_privatekey()

        ctx.set_verify(VERIFY_PEER | VERIFY_FAIL_IF_NO_PEER_CERT, self.verifyHostname)
        ctx.set_options(OP_NO_SSLv3)

        return ctx
    def verifyHostname(self, connection, x509, errno, depth, preverifyOK):
        print "Trying to verify file"
        if preverifyOK:
            if self.hostname == x509.get_subject().commonName:
                return False
        return preverifyOK

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

