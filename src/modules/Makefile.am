# Makefile.am for network/src/modules
# $Id$

module_DATA = $(wildcard *.ycp) \
	SuSEFirewallInterfaces.pm
EXTRA_DIST = $(module_DATA)

DNS.ybc: ISDN.ybc
ISDN.ybc: Detection.ybc NetworkDevices.ybc
NetworkDevices.ybc: Provider.ybc Detection.ybc
Firewall.ybc: NetworkDevices.ybc DNS.ybc
Proxy.ybc: NetworkDevices.ybc ISDN.ybc
Routing.ybc: ISDN.ybc

YCPCFLAGS =

idirs := lan isdn modem dsl installation provider remote services
../network:
	ln -sf routines $@
../network/%: ../network
	ln -sf ../$* $@

ycpchook = ../network $(foreach idir, $(idirs), ../network/$(idir))

include $(top_srcdir)/Makefile.am.common
CLEANFILES += $(ycpchook)
