require "yast"
require "y2network/config"
require "y2network/virtual_interface"
require "y2network/connection_config/ethernet"
require "y2network/connection_config/bonding"
require "y2network/connection_config/bridge"
require "y2network/connection_config/wireless"
require "y2network/connection_config/vlan"

# Historically yast2-network has been tightly coupled to ifconfig or wicked
# configuration. One of the goals of the new network-ng is to be backend
# agnostic supporting network configuration profiles like nanny policies
# (wicked) or network connections (NM).
#
# With that in mind and based somehow in NetworkManager we have introduced a
# new ConnectionConfig class for storing a group of settings that could belong
# to an specific interface or not. There are some generic settings and some
# that are type specific.
#
# We could have multiple connections with the same interface name associated
# but only one active based on different conditions (home vs office connection,
# speed based etc...)
#
# Below we will show an example of how the new 'ConnectionConfig' could be used
# to configure this network topology assuming physical interfaces are part of
# current interfaces config list:
#
#         ###########      ###############     ##############
#         #  bond0  #------#  bond0.100  #-----#  virbr100  #
#         ###########      ###############     ##############
#              |
#        -------------
#       |             |
#  ##########    ##########    ##########     ###########
#  #  eth1  #    #  eth2  #    #  eth0  #     #  wlan0  #
#  ##########    ##########    ##########     ###########
#

config = Y2Network::Config.from(:sysconfig)

eth1 = config.interfaces.by_name("eth1")
eth2 = config.interfaces.by_name("eth2")
bond = Y2Network::ConnectionConfig::Bonding.new
bond.slaves = [eth1, eth2]
bond.options = "mode=active-backup miimon=100"
bond.interface = Y2Network::VirtualInterface.new("bond0")
config.interfaces << bond.interface

vlan100 = Y2Network::ConnectionConfig::Vlan.new
vlan100.etherdevice = bond.interface
vlan100.vlan_id = "100"
vlan100.interface = Y2Network::VirtualInterface.new("bond0.100")

virbr100 = Y2Network::ConnectionConfig::Bridge.new
virbr100.ports = [vlan100.interface]
virbr100.interface = Y2Network::VirtualInterface.new("virbr100")

eth0 = config.interfaces.by_name("eth0")
eth_conn = Y2Network::ConnectionConfig::Ethernet.new
eth_conn.interface = eth0

wlan0 = config.interfaces.by_name("wlan0")
wlan_conn = Y2Network::ConnectionConfig::Wireless.new
wlan_conn.essid = "TEST_WIFI"
wlan_conn.interface = wlan0
