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
require "y2network/hostname_reader"

Yast.import "Mode"

module Y2Network
  module Sysconfig
    # Reads DNS configuration from sysconfig files
    class DNSReader
      include Yast::Logger

      # Return configuration from sysconfig files
      #
      # @return [Y2Network::DnsConfig] DNS configuration
      def config
        installer = Yast::Mode.installation || Yast::Mode.autoinst
        Y2Network::DNS.new(
          nameservers:        nameservers,
          hostname:           hostname,
          save_hostname:      !installer || hostname_from_install_inf?,
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

          ips << IPAddr.new(str)
        rescue IPAddr::InvalidAddressError
          log.warn "Invalid IP address: #{str}"

        end
      end

      # Returns the resolv.conf update policy
      #
      # @return [String]
      def resolv_conf_policy
        value = Yast::SCR.Read(
          Yast::Path.new(".sysconfig.network.config.NETCONFIG_DNS_POLICY")
        )
        (value.nil? || value.empty?) ? "default" : value
      end

      # Returns the hostname
      #
      # @return [String]
      def hostname
        @hostname_reader = HostnameReader.new
        @hostname_reader.hostname
      end

      # Checks whether the hostname was read from install.inf
      #
      # @return [Boolean]
      def hostname_from_install_inf?
        !@hostname_reader.install_inf_hostname.nil?
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
