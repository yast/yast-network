# Makefile.am for network/src/installation
# $Id$

yncludedir = @yncludedir@/network/installation
ynclude_DATA = dialogs.ycp

ybin_SCRIPTS = cut-messages

client_DATA = inst_ask_net_test.ycp inst_do_net_test.ycp	\
	inst_netprobe.ycp inst_netsetup.ycp

EXTRA_DIST = $(ynclude_DATA) $(client_DATA) $(ybin_SCRIPTS)

include $(top_srcdir)/Makefile.am.common
