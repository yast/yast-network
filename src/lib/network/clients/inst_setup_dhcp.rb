require "network/network_autoconfiguration"

module Yast
  class SetupDhcp
    include Singleton
    include Logger

    def main
      nac = Yast::NetworkAutoconfiguration.instance
      if !nac.any_iface_active?
        nac.configure_dhcp
      else
        log.info("Automatic DHCP configuration not started - an interface is already configured")
      end

      # if this is not wrapped in a def, ruby -cw says
      # warning: possibly useless use of a literal in void context
      :next
    end
  end
end
