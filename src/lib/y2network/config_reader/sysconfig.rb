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
require "y2network/sysconfig_paths"
require "y2network/routing_table"
require "y2network/sysconfig_routes_file"

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
        routing_tables = find_routing_tables
        routing = Routing.new(
          tables: routing_tables, forward_ipv4: forward_ipv4?, forward_ipv6: forward_ipv6?
        )

        Config.new(interfaces: interfaces, routing: routing, source: :sysconfig)
      end

    private

      include SysconfigPaths

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
      def find_routing_tables
        main_routes = load_routes_from
        iface_routes = find_interfaces.flat_map do |iface|
          load_routes_from("/etc/sysconfig/network/ifroute-#{iface.name}")
        end
        all_routes = main_routes + iface_routes
        [Y2Network::RoutingTable.new(all_routes.uniq)]
      end

      # Load a set of routes for a given path
      def load_routes_from(path = nil)
        file = Y2Network::SysconfigRoutesFile.new(path)
        file.load
        file.routes
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
