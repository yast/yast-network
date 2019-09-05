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
require "y2network/dns"
require "y2network/sysconfig/interface_file"

Yast.import "Hostname"
Yast.import "Mode"
Yast.import "IP"
Yast.import "FileUtils"
Yast.import "NetHwDetection"

module Y2Network
  module Sysconfig
    # Reads DNS configuration from sysconfig files
    class DNSReader
      include Yast::Logger

      # Return configuration from sysconfig files
      #
      # @return [Y2Network::DnsConfig] DNS configuration
      def config
        Y2Network::DNS.new(
          nameservers:        nameservers,
          hostname:           hostname,
          searchlist:         searchlist,
          resolv_conf_policy: resolv_conf_policy,
          dhcp_hostname:      dhcp_hostname
        )
      end

    private

      # Nameservers from sysconfig
      #
      # Does not include invalid addresses
      #
      # @return [Array<IPAddr>]
      def nameservers
        servers = Yast::SCR.Read(
          Yast::Path.new(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS")
        ).to_s.split

        servers.each_with_object([]) do |str, ips|
          begin
            ips << IPAddr.new(str)
          rescue IPAddr::InvalidAddressError
            log.warn "Invalid IP address: #{str}"
          end
        end
      end

      # Returns the resolv.conf update policy
      #
      # @return [String]
      def resolv_conf_policy
        value = Yast::SCR.Read(
          Yast::Path.new(".sysconfig.network.config.NETCONFIG_DNS_POLICY")
        )
        value.nil? || value.empty? ? "default" : value
      end

      # Returns the hostname
      #
      # @return [String]
      def hostname
        if (Yast::Mode.installation || Yast::Mode.autoinst) && Yast::FileUtils.Exists("/etc/install.inf")
          fqdn = hostname_from_install_inf
        end

        return hostname_from_system if fqdn.nil? || fqdn.empty?
        host, _domain = *Yast::Hostname.SplitFQ(fqdn)
        host
      end

      # Reads the hostname from the /etc/install.inf file
      #
      # @return [String] Hostname
      def hostname_from_install_inf
        install_inf_hostname = Yast::SCR.Read(Yast::Path.new(".etc.install_inf.Hostname")) || ""
        log.info("Got #{install_inf_hostname} from install.inf")

        return "" if install_inf_hostname.empty?

        # if the name is actually IP, try to resolve it (bnc#556613, bnc#435649)
        if Yast::IP.Check(install_inf_hostname)
          fqdn = Yast::NetHwDetection.ResolveIP(install_inf_hostname)
          log.info("Got #{fqdn} after resolving IP from install.inf")
        else
          fqdn = install_inf_hostname
        end

        fqdn
      end

      # Reads the hostname from the underlying system
      #
      # @return [String] Hostname
      def hostname_from_system
        Yast::Execute.stdout.on_target!("/bin/hostname").strip
      end

      # Return the list of search domains
      #
      # @return [Array<String>]
      def searchlist
        Yast::SCR.Read(
          Yast::Path.new(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST")
        ).to_s.split
      end

      # Returns whether the hostname should be taken from DHCP
      #
      # @return [String,:any,:none] Interface to set the hostname based on DHCP settings;
      #   :any for any interface; :none for ignoring the hostname assigned via DHCP
      def dhcp_hostname
        value = Yast::SCR.Read(Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"))
        return :any if value == "yes"
        files = InterfaceFile.all
        file = files.find do |f|
          f.load
          f.dhclient_set_hostname == "yes"
        end
        file ? file.interface : :none
      end
    end
  end
end
