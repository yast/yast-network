# Makefile.am for network/src/modules
# $Id$

module_DATA = $(wildcard *.ycp) \
	SuSEFirewallInterfaces.pm
EXTRA_DIST = $(module_DATA)

NetworkDevices.ybc: Provider.ybc
Firewall.ybc: NetworkDevices.ybc DNS.ybc
Proxy.ybc: NetworkDevices.ybc

YCPCFLAGS =

network:
	ln -sf ../routines $@

network/isdn: network
	ln -sf ../isdn $@

network/lan: network
	ln -sf ../lan $@

ycpchook = network network/isdn network/lan

include $(top_srcdir)/Makefile.am.common
