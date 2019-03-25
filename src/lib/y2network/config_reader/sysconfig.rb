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
require "y2network/routing_config"
require "y2network/routing_helpers"

Yast.import "NetworkInterfaces"
Yast.import "Routing"

module Y2Network
  module ConfigReader
    # This class reads the current configuration from `/etc/sysconfig` files
    class Sysconfig
      include RoutingHelpers

      # @return [Y2Network::Config] Network configuration
      def config
        interfaces = find_interfaces
        Config.new(
          interfaces: interfaces,
          routing:    find_routing_config(interfaces),
          source:     :sysconfig
        )
      end

      def find_routing_config(interfaces)
        Yast::Routing.Read
        tables = find_routing_tables(interfaces)
        Y2Network::RoutingConfig.new(
          tables:     tables,
          forward_v4: Yast::Routing.Forward_v4,
          forward_v6: Yast::Routing.Forward_v6
        )
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
        routes = Yast::Routing.Routes.map { |h| build_route(interfaces, h) }
        table = Y2Network::RoutingTable.new(routes)
        [table]
      end
    end
  end
end
