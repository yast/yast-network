# Makefile.am for network/src/modules
# $Id$

module_DATA = $(wildcard *.ycp)
EXTRA_DIST = $(module_DATA)

DNS.ybc: ISDN.ybc
ISDN.ybc: Detection.ybc
NetworkDevices.ybc: Provider.ybc Detection.ybc
Firewall.ybc: DNS.ybc
Proxy.ybc: ISDN.ybc
Routing.ybc: ISDN.ybc

YCPCFLAGS =

idirs := lan isdn modem dsl installation provider remote services
nidirs = $(foreach idir, $(idirs), network/$(idir))
network:
	ln -sf ../routines $@
${nidirs}: network/%: network
	ln -sf ../$* $@

ycpchook = network ${nidirs}

include $(top_srcdir)/Makefile.am.common
CLEANFILES += $(ycpchook)
