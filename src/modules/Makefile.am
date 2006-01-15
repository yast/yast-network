# Makefile.am for network/src/modules
# $Id$

module_DATA = $(wildcard *.ycp)
EXTRA_DIST = $(module_DATA)

YCPCFLAGS =

idirs := lan isdn modem dsl installation provider remote services
nidirs = $(foreach idir, $(idirs), network/$(idir))
network:
	test -L $@ || ln -snf ../routines $@
${nidirs}: network/%: network
	test -L $@ || ln -snf ../$* $@

ycpchook = network ${nidirs}

include $(top_srcdir)/Makefile.am.common
CLEANFILES += $(ycpchook)
