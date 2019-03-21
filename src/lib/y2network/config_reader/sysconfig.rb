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
require "y2network/config"
require "y2network/interface"
require "y2network/routing_table"
require "y2network/route"

Yast.import "NetworkInterfaces"
Yast.import "Routing"

module Y2Network
  module ConfigReader
    # This class reads the current configuration from `/etc/sysconfig` files
    class Sysconfig
      # @return [Y2Network::Config] Network configuration
      def config
        interfaces = find_interfaces
        routing_tables = find_routing_tables(interfaces)
        Config.new(interfaces: interfaces, routing_tables: routing_tables)
      end

    private

      MISSING_VALUE = "-".freeze
      private_constant :MISSING_VALUE

      # Find configured network interfaces
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

      # Find routing tables
      #
      # @note For the time being, only one routing table is considered.
      #
      # @param interfaces [Array<Interface>] Detected interfaces
      # @return [Array<RoutingTable>]
      #
      # @see Yast::Routing.Routes
      def find_routing_tables(interfaces)
        Yast::Routing.Read
        routes = Yast::Routing.Routes.map { |h| build_route(interfaces, h) }
        table = Y2Network::RoutingTable.new(routes)
        [table]
      end

      # Build a route given a hash from the SCR agent
      #
      # @param interfaces [Array<Interface>] List of detected interfaces
      # @param hash [Hash] Hash from the `.routes` SCR agent
      # @return Route
      def build_route(interfaces, hash)
        iface = interfaces.find { |i| i.name == hash["device"] }
        Y2Network::Route.new(
          to:        build_ip(hash["destination"], hash["netmask"]) || :default,
          interface: iface,
          gateway:   build_ip(hash["gateway"], MISSING_VALUE)
        )
      end

      # Given an IP and a netmaks, returns a valid IPAddr objecto
      #
      # @param ip_str      [String] IP address; {MISSING_VALUE} means that the IP is not defined
      # @param netmask_str [String] Netmask; {MISSING_VALUE} means than no netmaks was specified
      # @return [IPAddr,nil] The IP address or `nil` if the IP is missing
      def build_ip(ip_str, netmask_str = nil)
        return nil if ip_str == MISSING_VALUE
        ip = IPAddr.new(ip_str)
        netmask_str == MISSING_VALUE ? ip : ip.mask(netmask_str)
      end
    end
  end
end
