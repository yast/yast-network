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
require "y2network/dns_config"

module Y2Network
  module ConfigReader
    # Reads DNS configuration from sysconfig files
    class SysconfigDNS
      include Yast::Logger

      # Return configuration from sysconfig files
      #
      # @return [Y2Network::DnsConfig] DNS configuration
      def config
        Y2Network::DNSConfig.new(
          name_servers:        name_servers,
          hostname:           hostname,
          search_domains:     search_domains,
          resolv_conf_policy: resolv_conf_policy,
          hostname_to_hosts:  hostname_to_hosts,
          dhcp_hostname:      dhcp_hostname
        )
      end

    private

      # Name servers from sysconfig
      #
      # Does not include invalid addresses
      #
      # @return [Array<IPAddr>]
      def name_servers
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
        Yast::Execute.stdout.on_target!("/bin/hostname").strip
      end

      # Return the list of search domains
      #
      # @return [Array<String>]
      def search_domains
        Yast::SCR.Read(
          Yast::Path.new(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST")
        ).to_s.split
      end

      # Returns whether the hostname should be added to /etc/hosts
      #
      # @return [Boolean]
      def hostname_to_hosts
        value = Yast::SCR.Read(Yast::Path.new(".sysconfig.network.dhcp.WRITE_HOSTNAME_TO_HOSTS"))
        value == "yes"
      end

      # Returns whether the hostname should be taken from DHCP
      #
      # @return [Boolean]
      def dhcp_hostname
        value = Yast::SCR.Read(Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"))
        value == "yes"
      end
    end
  end
end
