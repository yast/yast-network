# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2network/config"
require "y2network/virtual_interface"
require "y2network/connection_config/ethernet"
require "y2network/connection_config/bonding"
require "y2network/connection_config/wireless"

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
# to configure our network.

# given an interfaces list (interfaces)

config = Y2Network::Config.from(:wicked)

eth0 = config.interfaces.by_name("eth0")
eth_conn = Y2Network::ConnectionConfig::Ethernet.new
eth_conn.interface = eth0

eth1 = config.interfaces.by_name("eth1")
eth2 = config.interfaces.by_name("eth2")
bond = Y2Network::ConnectionConfig::Bonding.new
bond.slaves = [eth1, eth2]
bond.options = "mode=active-backup miimon=100"
bond.interface = Y2Network::VirtualInterface.new("bond0")
config.interfaces << bond.interface

wlan0 = config.interfaces.by_name("wlan0")
wlan_conn = Y2Network::ConnectionConfig::Wireless.new
wlan_conn.essid = "TEST_WIFI"
wlan_conn.interface = wlan0
