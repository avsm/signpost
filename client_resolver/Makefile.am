# This file is part of nss-signpost.
#
# Copyright 2008 Lennart Poettering
#
# nss-signpost is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation, either version 2.1 of
# the License, or (at your option) any later version.
#
# nss-signpost is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with nss-signpost. If not, If not, see
# <http://www.gnu.org/licenses/>.

ACLOCAL_AMFLAGS = -I m4

lib_LTLIBRARIES = libnss_signpost.la

bin_PROGRAMS = unbound-host signpost-test 


EXTRA_DIST=bootstrap.sh # README LICENSE

AM_CPPFLAGS = -include $(top_builddir)/config.h
AM_LDFLAGS = -lldns -lunbound
# MAINTAINERCLEANFILES=README
# noinst_DATA = README

# README:
# 	rm -f README
# 	$(MAKE) -C doc README
# 	cd $(srcdir) && ln -s doc/README README

libnss_signpost_la_SOURCES = \
	nss-signpost.c \
	ifconf.h

if LEGACY
libnss_signpost_la_SOURCES += legacy.c
else
libnss_signpost_la_SOURCES += netlink.c
endif

libnss_signpost_la_LDFLAGS = \
	-avoid-version \
	-module \
	-export-dynamic \
	-shrext .so.2 \
	-lldns \
	-lunbound 



unbound_host_SOURCES = unbound-host.c 
signpost_test_SOURCES = signpost-test.c

install-exec-hook:
	rm -f $(DESTDIR)$(libdir)/libnss_signpost.la
	rm -f $(DESTDIR)$(libdir)/libnss_signpost_minimal.la

uninstall-hook:
	rm -f $(DESTDIR)$(libdir)/libnss_signpost.so.2
	rm -f $(DESTDIR)$(libdir)/libnss_signpost_minimal.so.2
