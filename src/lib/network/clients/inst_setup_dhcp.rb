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

require "network/network_autoconfiguration"

Yast.import "Linuxrc"
Yast.import "DNS"
Yast.import "Systemd"
Yast.import "NetworkService"

module Yast
  class SetupDhcp
    include Singleton
    include Logger

    def main
      nac = NetworkAutoconfiguration.instance
      set_dhcp_hostname! if Stage.initial

      if Yast::NetworkService.wicked?
        if nac.any_iface_active?
          log.info("Automatic DHCP configuration not started - an interface is already configured")
        else
          nac.configure_dhcp
        end
      else
        log.info("Network is not managed by wicked, skipping DHCP setup")
      end

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
      set_dhcp_hostname =
        set_hostname_used? ? set_dhcp_hostname? : DNS.default_dhcp_hostname

      log.info("Write dhcp hostname default: #{set_dhcp_hostname}")
      DNS.dhcp_hostname = set_dhcp_hostname ? :any : :none
      SCR.Write(
        Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"),
        (DNS.dhcp_hostname == :any) ? "yes" : "no"
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
