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
require "y2network/config"
require "y2network/interface"
require "y2network/routing"
require "y2network/routing_table"
require "y2network/route"
require "y2network/config_reader/sysconfig_routes_reader"

Yast.import "NetworkInterfaces"

module Y2Network
  module ConfigReader
    # This class reads the current configuration from `/etc/sysconfig` files
    class Sysconfig
      def initialize(_opts = {})
      end

      # @return [Y2Network::Config] Network configuration
      def config
        interfaces = find_interfaces
        routing = Routing.new(tables: [load_routes], forward_ipv4: forward_ipv4?, forward_ipv6: forward_ipv6?)

        Config.new(interfaces: interfaces, routing: routing, source: :sysconfig)
      end

    private

      # sysctl keys, used as *single* SCR path components below
      IPV4_SYSCTL = "net.ipv4.ip_forward".freeze
      IPV6_SYSCTL = "net.ipv6.conf.all.forwarding".freeze
      # SCR paths
      SYSCTL_AGENT_PATH = ".etc.sysctl_conf".freeze
      SYSCTL_IPV4_PATH = (SYSCTL_AGENT_PATH + ".\"#{IPV4_SYSCTL}\"").freeze
      SYSCTL_IPV6_PATH = (SYSCTL_AGENT_PATH + ".\"#{IPV6_SYSCTL}\"").freeze

      # Find configured network interfaces
      #
      # Configured interfaces have a configuration (ifcfg file) assigned.
      #
      # @return [Array<Interface>] Detected interfaces
      # @see Yast::NetworkInterfaces.Read
      def find_interfaces
        Yast::NetworkInterfaces.Read
        # TODO: for the time being, we are just relying in the underlying stuff.
        Yast::NetworkInterfaces.List("").map do |name|
          Y2Network::Interface.new(name)
        end
      end

      # Reads routes
      #
      # Merges routes from /etc/sysconfig/network/routes and /etc/sysconfig/network/ifroute-*
      # TODO: currently it implicitly loads main/default routing table
      #
      # return [RoutingTable] an object with routes
      def load_routes
        # load /etc/sysconfig/network/routes
        routing_table = SysconfigRoutesReader.new.config
        # load /etc/sysconfig/network/ifroute-*
        dev_routing_tables = find_interfaces.map do |iface|
          SysconfigRoutesReader.new(
            routes_file: "/etc/sysconfig/network/ifroute-#{iface.name}"
          ).config
        end

        dev_routing_tables.reduce(routing_table) do |rt, dev_rt|
          rt.concat(dev_rt.routes)
        end
        routing_table.routes.uniq!
        routing_table
      end

      # Reads IPv4 forwarding status
      #
      # return [Boolean] true when IPv4 forwarding is allowed
      def forward_ipv4?
        Yast::SCR.Read(Yast::Path.new(SYSCTL_IPV4_PATH)) == "1"
      end

      # Reads IPv6 forwarding status
      #
      # return [Boolean] true when IPv6 forwarding is allowed
      def forward_ipv6?
        Yast::SCR.Read(Yast::Path.new(SYSCTL_IPV6_PATH)) == "1"
      end
    end
  end
end
