require "y2network/connection/ethernet"
require "y2network/connection/bond"
require "y2network/connection/wireless"

# given an interfaces list (interfaces)

eth0 = config.interfaces.find("eth0")
eth_conn = Y2Network::Connection::Ethernet.new
eth_conn.interface = eth0

eth1 = config.interfaces.find("eth1")
eth2 = config.interfaces.find("eth2")
bond = Y2Network::Connection::Bond.new
bond.slaves = [eth1, eth2]
bond.options = "mode=active-backup miimon=100"
bond.interface = Y2Network::VirtualInterface.new("bond0")
config.interfaces << bond

wlan0 = config.interfaces.find("wlan0")
wlan_conn = Y2Network::Connection::Wireless.new
wlan_conn.essid = "TEST_WIFI"
wlan_conn.interface = wlan0
