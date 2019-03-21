require "ipaddr"

require "cwm/popup"
require "y2network/route"
require "y2network/widgets/destination"
require "y2network/widgets/devices"
require "y2network/widgets/gateway"
require "y2network/widgets/route_options"

Yast.import "Label"

module Y2Network
  module Dialogs
    # Dialog to create or edit route.
    class Route < CWM::Popup
      # @param route is now term from table, but it should be object for single route
      def initialize(route, available_devices)
        log.info "route dialog with route: #{route.inspect} " \
          "and devices #{available_devices.inspect}"
        params = route.params
        @route_id = params[0]
        # TODO: netmask
        @route = ::Y2Network::Route.new(
          to:        (params[1] || "-") == "-" ? :default : IPAddr.new(params[1]),
          interface: (params[4].nil? || params[4].empty?) ? :any : params[4],
          gateway:   (params[2] || "-" ) == "-" ? nil : IPAddr.new(params[2]),
          options:   params[5] || ""
        )

        @available_devices = available_devices
      end

      def run
        res = super
        log.info "route dialog result #{res.inspect}"
        return nil if res != :ok

        Yast::Term.new(
          :item,
          @route_id,
          @route.to == :default ? "-" : @route.to.to_s,
          @route.gateway.nil? ? "-" : @route.gateway.to_s,
          "-", # TODO: netmask
          @route.interface == :any ? "" : @route.interface,
          @route.options
        )
      end

      def contents
        MinWidth(
          60,
          VBox(
            HBox(
              HWeight(100, Widgets::Destination.new(@route))
            ),
            HBox(
              HWeight(70, Widgets::Gateway.new(@route)),
              HSpacing(1),
              HWeight(30, Widgets::Devices.new(@route, @available_devices))
            ),
            Widgets::RouteOptions.new(@route)
          )
        )
      end
    end

    def next_button
      Yast::Label.OKButton
    end

    def back_button
      Yast::Label.CancelButton
    end

    def abort_button
      ""
    end
  end
end
