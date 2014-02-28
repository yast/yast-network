# Sources for network

module_DATA = \
  modules/LanUdevAuto.rb \
  modules/SuSEFirewall4Network.rb \
  modules/Remote.rb \
  modules/InternetDevices.rb \
  modules/NetworkStorage.rb \
  modules/Host.rb \
  modules/NetHwDetection.rb \
  modules/Routing.rb \
  modules/LanItems.rb \
  modules/Network.rb \
  modules/Lan.rb \
  modules/DNS.rb

module1dir = @moduledir@/YaPI
module1_DATA = \
  modules/YaPI/NETWORK.pm

client_DATA = \
  clients/inst_lan.rb \
  clients/remote_proposal.rb \
  clients/dns_auto.rb \
  clients/save_network.rb \
  clients/lan_auto.rb \
  clients/network.rb \
  clients/firewall_stage1_finish.rb \
  clients/inst_netprobe.rb \
  clients/inst_do_net_test.rb \
  clients/inst_setup_dhcp.rb \
  clients/routing.rb \
  clients/lan.rb \
  clients/host_auto.rb \
  clients/general_proposal.rb \
  clients/inst_ask_net_test.rb \
  clients/inst_hostname.rb \
  clients/firewall_stage1_proposal.rb \
  clients/routing_auto.rb \
  clients/remote.rb \
  clients/dns.rb \
  clients/lan_proposal.rb \
  clients/host.rb \
  clients/inst_install_inf.rb

yncludedir = @yncludedir@/network/installation
ynclude_DATA = \
  include/network/installation/dialogs.rb

ynclude1dir = @yncludedir@/network
ynclude1_DATA = \
  include/network/runtime.rb \
  include/network/hardware.rb \
  include/network/widgets.rb \
  include/network/devices.rb \
  include/network/summary.rb \
  include/network/complex.rb \
  include/network/routines.rb

ynclude2dir = @yncludedir@/network/services
ynclude2_DATA = \
  include/network/services/routing.rb \
  include/network/services/dns.rb \
  include/network/services/host.rb

ynclude5dir = @yncludedir@/network/remote
ynclude5_DATA = \
  include/network/remote/dialogs.rb

ynclude6dir = @yncludedir@/network/lan
ynclude6_DATA = \
  include/network/lan/wireless.rb \
  include/network/lan/hardware.rb \
  include/network/lan/wizards.rb \
  include/network/lan/s390.rb \
  include/network/lan/udev.rb \
  include/network/lan/dhcp.rb \
  include/network/lan/bridge.rb \
  include/network/lan/complex.rb \
  include/network/lan/help.rb \
  include/network/lan/address.rb \
  include/network/lan/virtual.rb \
  include/network/lan/cards.rb \
  include/network/lan/cmdline.rb

scrconf_DATA = \
  scrconf/cfg_udev_persistent.scr \
  scrconf/etc_hosts.scr \
  scrconf/cfg_dhcp.scr \
  scrconf/cfg_network.scr \
  scrconf/routes.scr

agent_SCRIPTS = \
  servers_non_y2/ag_udev_persistent

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/host.rnc \
  autoyast-rnc/networking.rnc

ybin_SCRIPTS = \
  bin/cut-messages

desktop_DATA = \
  desktop/host.desktop \
  desktop/network.desktop \
  desktop/remote.desktop \
  desktop/lan.desktop

ylibdir = @ylibdir@/network
ylib_DATA = \
  lib/network/edit_nic_name.rb \
  lib/network/confirm_virt_proposal.rb \
  lib/network/install_inf_convertor.rb

EXTRA_DIST = \
  $(module_DATA) \
  $(module1_DATA) \
  $(client_DATA) \
  $(ynclude_DATA) \
  $(ynclude1_DATA) \
  $(ynclude2_DATA) \
  $(ynclude5_DATA) \
  $(ynclude6_DATA) \
  $(scrconf_DATA) \
  $(agent_SCRIPTS) \
  $(schemafiles_DATA) \
  $(ybin_SCRIPTS) \
  $(desktop_DATA) \
  $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common
