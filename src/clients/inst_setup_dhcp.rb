require "yast"
require "network/network_autoconfiguration"

def main
  Yast::NetworkAutoconfiguration.instance.configure_dhcp

  # if this is not wrapped in a def, ruby -cw says
  # warning: possibly useless use of a literal in void context
  :next
end

main
