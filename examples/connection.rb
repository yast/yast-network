require "yast"
require "y2network/config"
require "y2network/virtual_interface"
require "y2network/connection_config/ethernet"
require "y2network/connection_config/bond"
require "y2network/connection_config/wireless"

# given an interfaces list (interfaces)

config = Y2Network::Config.from(:sysconfig)

eth0 = config.interfaces.find("eth0").first
eth_conn = Y2Network::ConnectionConfig::Ethernet.new
eth_conn.interface = eth0

eth1 = config.interfaces.find("eth1").first
eth2 = config.interfaces.find("eth2").first
bond = Y2Network::ConnectionConfig::Bond.new
bond.slaves = [eth1, eth2]
bond.options = "mode=active-backup miimon=100"
bond.interface = Y2Network::VirtualInterface.new("bond0")
config.interfaces << bond

wlan0 = config.interfaces.find("wlan0").first
wlan_conn = Y2Network::ConnectionConfig::Wireless.new
wlan_conn.essid = "TEST_WIFI"
wlan_conn.interface = wlan0
