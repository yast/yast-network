#
# Makefile.am for y2c_network/src
#
# $Id$
#

clientsdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/network
menudir = $(YAST2DIR)/menuentries
modulesdir = $(YAST2DIR)/modules

clients_DATA =			\
	network.ycp		\
	network_auto.ycp	\
	network_summary.ycp	\
	network_write.ycp

include_DATA =			\
	helps.ycp		\
	misc.ycp		\
	ui.ycp

menu_DATA =			\
	menuentry_network.y2cc

modules_DATA =			\
	Network.ycp

EXTRA_DIST = $(clients_DATA) $(include_DATA) $(menu_DATA) $(modules_DATA)
