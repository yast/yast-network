require "network/network_autoconfiguration"

Yast.import "Linuxrc"
Yast.import "DNS"

module Yast
  class SetupDhcp
    include Singleton
    include Logger

    def main
      nac = NetworkAutoconfiguration.instance
      set_dhcp_hostname! if Stage.initial

      if !nac.any_iface_active?
        nac.configure_dhcp
      else
        log.info("Automatic DHCP configuration not started - an interface is already configured")
      end

      # if this is not wrapped in a def, ruby -cw says
      # warning: possibly useless use of a literal in void context
      :next
    end

    # Check if set of DHCLIENT_SET_HOSTNAME in /etc/sysconfig/network/dhcp has
    # been disable by linuxrc cmdline
    #
    # @return [Boolean] false if sethostname=0; true otherwise
    def set_dhcp_hostname?
      set_hostname = Linuxrc.InstallInf("SetHostname")
      log.info("SetHostname: #{set_hostname}")
      set_hostname != "0"
    end

    # Write the DHCLIENT_SET_HOSTNAME in /etc/sysconfig/network/dhcp based on
    # linuxrc sethostname cmdline option if provided or the default value
    # defined in the control file if not.
    def set_dhcp_hostname!
      DNS.dhcp_hostname =
        set_hostname_used? ? set_dhcp_hostname? : DNS.default_dhcp_hostname

      log.info("Write dhcp hostname default: #{DNS.dhcp_hostname}")
      SCR.Write(
        Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"),
        DNS.dhcp_hostname ? "yes" : "no"
      )
      # Flush cache
      SCR.Write(
        Yast::Path.new(".sysconfig.network.dhcp"),
        nil
      )
    end

    # Check whether the linuxrc sethostname option has been used or not
    #
    # @return [Boolean] true if sethosname linuxrc cmdline option was given
    def set_hostname_used?
      Linuxrc.InstallInf("SetHostnameUsed") == "1"
    end
  end
end
