require "yast"
require "network/network_autoconfiguration"

Yast::NetworkAutoconfiguration.instance.configure_dhcp

:next
