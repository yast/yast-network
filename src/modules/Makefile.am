# Makefile.am for network/src/modules
# $Id$

module_DATA = $(wildcard *.ycp)
EXTRA_DIST = $(module_DATA)

NetworkDevices.ybc: Provider.ybc

YCPCFLAGS = -M. -I.

network:
	ln -sf ../routines network

network/isdn:
	ln -sf ../isdn network/isdn

ycpchook = network network/isdn

include $(top_srcdir)/Makefile.am.common
