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

require "ipaddr"

require "cwm/table"
require "y2network/interface"

Yast.import "Label"
Yast.import "Lan"

module Y2Network
  module Widgets
    class RoutingTable < CWM::Table
      def initialize(routing_table)
        textdomain "network"

        @routing_table = routing_table
      end

      def header
        [
          _("Destination"),
          _("Gateway"),
          _("Device"),
          Yast::Label.Options.delete("&")
        ]
      end

      def items
        @routing_table.routes.map.each_with_index do |route, index|
          [
            index,
            route.to.yield_self do |to|
              (to == :default) ? "default" : (to.to_s + "/" + to.prefix.to_s)
            end,
            route.gateway.nil? ? "-" : route.gateway.to_s,
            route.interface.nil? ? "-" : route.interface.name,
            route.options.to_s
          ]
        end
      end

      # TODO: just workaround to make it work with old hash based CWM
      def init
        redraw_table
        disable if config.backend?(:network_manager)
      end

      def selected_route
        return nil unless value

        @routing_table.routes[value]
      end

      def add_route(route)
        @routing_table.routes << route

        redraw_table
      end

      # Replaces selected route with new one
      def replace_route(route)
        @routing_table.routes[value] = route

        redraw_table
      end

      # deletes selected route
      def delete_route
        @routing_table.routes.delete_at(value)

        redraw_table
      end

      def redraw_table
        change_items(items)
      end

      def config
        Yast::Lan.yast_config
      end
    end
  end
end
