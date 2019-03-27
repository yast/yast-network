require "ipaddr"

require "cwm/table"
require "y2network/interface"

Yast.import "Label"

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
              to == :default ? "default" : (to.to_s + "/" + to.prefix.to_s)
            end,
            route.gateway.nil? ? "-" : route.gateway.to_s,
            route.interface == :any ? "-" : route.interface.name,
            route.options.to_s
          ]
        end
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
    end
  end
end
