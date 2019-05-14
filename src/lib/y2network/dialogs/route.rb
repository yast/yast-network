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
      # @param route [Y2Network::Route]
      # @param available_devices[Array<Interface>] list of known interfaces
      def initialize(route, available_devices)
        log.info "route dialog with route: #{route.inspect} " \
          "and devices #{available_devices.inspect}"
        @route = route
        @available_devices = available_devices
      end

      def contents
        devices = @available_devices.map(&:name) + [""]
        MinWidth(
          60,
          VBox(
            HBox(
              HWeight(100, Widgets::Destination.new(@route))
            ),
            HBox(
              HWeight(70, Widgets::Gateway.new(@route)),
              HSpacing(1),
              HWeight(30, Widgets::Devices.new(@route, devices))
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
