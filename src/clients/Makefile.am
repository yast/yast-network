# Makefile.am for y2c_network/src/clients
# $Id$

client_DATA = $(wildcard *.ycp)
EXTRA_DIST = $(client_DATA)

YCPCFLAGS = -M../modules -I../modules
# the rest has been already done in ../modules
network:
	ln -sf ../routines $@
ycpchook = network
include $(top_srcdir)/Makefile.am.common
CLEANFILES += $(ycpchook)
