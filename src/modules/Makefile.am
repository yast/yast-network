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

network:
	ln -sf ../routines $@

network/isdn: network
	ln -sf ../isdn $@

network/lan: network
	ln -sf ../lan $@

ycpchook = network network/isdn network/lan

include $(top_srcdir)/Makefile.am.common
