# Makefile.am for network/src/modules

module_DATA = $(wildcard *.ycp)
EXTRA_DIST = $(module_DATA)

NetworkDevices.ybc: Provider.ybc

YCPCFLAGS = -M. -I.

network:
	ln -sf ../routines network

ycpchook = network


include $(top_srcdir)/Makefile.am.common
