require "ipaddr"

require "cwm/table"

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
        @routing_table.routes.each_with_index do |route, index|
          [
            index,
            route.to.yield_self do |to|
              to == :default ? "default" : (to.to_s + "/" + to.prefix.to_s)
            end,
            route.gateway.nil? ? "-" : route.gateway.to_s,
            route.device.to_s,
            route.options.to_s
          ]
        end
      end

      def store
        @routing_table.clear
        items = Yast::UI.QueryWidget(Id(widget_id), :Items)
        log.info "storing routing #{items.inspect}"

        items.each do |item|
          _id, destination, gateway, device, options = item.params
          destination = destination == "default" ? :default : IPAddr.new(destination)
          gateway = gateway == "-" ? "nil" : IPAddr.new(gateway)
          r = Route.new(to: destination, gateway: gateway, device: device, options: options)
          @routing_table.routes << r
        end
      end
    end
  end
end
