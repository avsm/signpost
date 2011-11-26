#!/usr/bin/env python

import sys, base64
#from pyasn1.type import univ, namedtype, tag
from Crypto.Util import asn1
from Crypto.PublicKey import DSA

"""
this script is used to translate dnssec keys to equivalent 
ssl private keys. In order to check if the key is correctly generated you can
run the coomand  openssl dsa -in out.pem -modulus -noout and compare the result 
with the base64 decoded public key in the DNSKEY record
"""

def export_dsa_key(p, q, g, x, y):
	seq = asn1.DerSequence()
	seq[:] = [ 0, p, q, g, y, x ]
	exported_key = ("-----BEGIN DSA PRIVATE KEY-----\n%s-----END DSA PRIVATE KEY-----" % 
		seq.encode().encode("base64"))
	print exported_key
	return exported_key

def array_to_hex(p):
	ret = ""
	for c in p:
		ret = "%s:%02x"%(ret, ord(c))
	return ret

if (len(sys.argv) < 2):
	print "Invalid number of arguments"
	sys.exit(1)

def string_to_long(p):
	ret = ""
	for c in p:
		ret = "%s%02x"%(ret, ord(c))
	# print ret
	return long(ret, 16)

# dsa param 
p = 0L
q = 0L
g = 0L
x = 0L
y = 0L

for line in open(sys.argv[1]):
	fields = line.split(" ")
	if(len(fields) == 2):
		# parsing parameter p
		if(fields[0] == "Prime(p):"):
			p=string_to_long(base64.decodestring(fields[1]))

		# parsing parameter q
		if(fields[0] == "Subprime(q):"):
			q = string_to_long(base64.decodestring(fields[1]))

		# parsing parameter g
		if(fields[0] == "Base(g):"):
			g = string_to_long(base64.decodestring(fields[1]))
		
		# parsing parameter x
		if(fields[0] == "Private_value(x):"):
			x = string_to_long(base64.decodestring(fields[1]))
	
		# parsing parameter g
		if(fields[0] == "Public_value(y):"):
			y = string_to_long(base64.decodestring(fields[1]))

if (p == 0L):
	print "param p not defined"
if (q == 0L):
	print "param q not defined"
if (g == 0L):
	print "param g not defined"
if (x == 0L):
	print "param x not defined"
if (y == 0L):
	print "param y not defined"

# print "%s %s %s %s %s" % (str(p), str(q), str(g), str(x), str(y))

f = open("out.pem", "w")
f.write( export_dsa_key(p, q, g, x, y))
##	print line
