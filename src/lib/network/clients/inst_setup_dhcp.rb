require "network/network_autoconfiguration"

module Yast
  class SetupDhcp
    include Singleton
    include Logger

    def initialize
      Yast.import "Linuxrc"
      Yast.import "DNS"
    end

    def main
      nac = NetworkAutoconfiguration.instance
      set_dhcp_hostname! if set_dhcp_hostname? && Stage.initial

      if !nac.any_iface_active?
        nac.configure_dhcp
      else
        log.info("Automatic DHCP configuration not started - an interface is already configured")
      end

      # if this is not wrapped in a def, ruby -cw says
      # warning: possibly useless use of a literal in void context
      :next
    end

    def set_dhcp_hostname?
      set_hostname = Linuxrc.InstallInf("SetHostname")
      log.info("SetHostname: #{set_hostname}")
      set_hostname != 0
    end

    def set_dhcp_hostname!
      DNS.dhcp_hostname = DNS.default_dhcp_hostname
      log.info("Write dhcp hostname default: #{DNS.dhcp_hostname}")
      SCR.Write(
        Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"),
        DNS.dhcp_hostname ? "yes" : "no"
      )
      SCR.Write(
        Yast::Path.new(".sysconfig.network.dhcp"),
        nil
      )
    end
  end
end
