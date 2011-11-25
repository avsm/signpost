from OpenSSL.SSL import Context, TLSv1_METHOD, VERIFY_PEER, OP_NO_SSLv3
from OpenSSL.SSL import VERIFY_CLIENT_ONCE, VERIFY_FAIL_IF_NO_PEER_CERT
from OpenSSL.crypto import load_certificate, FILETYPE_PEM
from twisted.internet.ssl import ContextFactory

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

