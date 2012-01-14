#!/usr/bin/env python

from routing import SP_routing
import dns_test

import ldns
import sys

import getopt

test_opt = dict(nameserver = [], data_dir = "./",
        tests = [], domain = "d3.signpo.st.")

optlist, args = getopt.getopt(sys.argv[1:], 'n:o:d:')

for opt in optlist:
    if opt[0] == "-n":
        print "looking name server %s"%(opt[1])
        test_opt["nameserver"].append(opt[1])
    elif opt[0] == "-o":
        test_opt["data_dir"] = opt[1] + "/"
    elif opt[0] == "-d":
        test_opt["domain"] = opt[1]
    else:
        print "unrecognised parameter %s"%(opt[0])

# define which test we will run
if len(args) > 0:
    for test in args:
        test = test.replace("/", ".")
        test = test.replace(".py", "")
        test_opt["tests"].append(test)
else:
    for test in glob.glob( os.path.join("tests/", '*.py') ):
        if "__init__.py" in test:
            continue
        test = test.replace("/", ".")
        test = test.replace(".py", "")
        test_opt["tests"].append(test)


# load routing information in order to know which device we need to
# monitor.
rt = SP_routing()

if len(test_opt["nameserver"]) == 0:
    print """No nameservers define, loading default nameserver from
    /etc/resolv.conf"""

    resolver = ldns.ldns_resolver.new_frm_file("/etc/resolv.conf")
    while resolver.nameserver_count() > 0:
        ns = resolver.pop_nameserver()
        test_opt["nameserver"].append(str(ns))

for ns in test_opt["nameserver"]:
    print "%s %s %s"%(ns, rt.get_gw_for_ip(str(ns)), rt.get_intf_for_ip(str(ns)))
    dns_test.run_test(str(ns),rt.get_intf_details(str(ns)), test_opt)
