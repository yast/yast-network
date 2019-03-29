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
require "y2network/routing"
require "y2network/routing_table"
require "y2network/route"
require "y2network/config_reader/sysconfig_routes_reader"

Yast.import "NetworkInterfaces"

module Y2Network
  module ConfigReader
    # This class reads the current configuration from `/etc/sysconfig` files
    class Sysconfig
      # @return [Y2Network::Config] Network configuration
      def config
        interfaces = find_interfaces
        routing = Routing.new(tables: [load_routes])

        Config.new(interfaces: interfaces, routing: routing, source: :sysconfig)
      end

    private

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
        routes = SysconfigRoutesReader.new.config
        # load /etc/sysconfig/network/ifroute-*
        dev_routes = find_interfaces.map do |iface|
          SysconfigRoutesReader.new(routes_file: "/etc/sysconfig/network/ifroute-#{iface.name}").config
        end

        dev_routes.inject(routes) { |memo, r| memo.concat(r.routes) }.uniq
      end
    end
  end
end
