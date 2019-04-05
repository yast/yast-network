require "y2network/interface"
require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Devices < CWM::ComboBox
      # @param route route object to get and store gateway value
      def initialize(route, available_devices)
        textdomain "network"

        @devices = available_devices
        @route = route
      end

      def label
        _("De&vice")
      end

      def help
        _(
          "<p><b>Device</b> specifies the device throught which the traffic" \
            " to the defined network will be routed.</p>"
        )
      end

      def items
        # TODO: maybe some translated names?
        @devices.map { |d| [d, d] }
      end

      def opt
        [:hstretch, :editable]
      end

      def init
        interface = @route.interface
        self.value = interface == :any ? "" : interface.name
      end

      def store
        interface = value
        @route.interface = interface.empty? ? :any : Interface.new(interface)
      end
    end
  end
end
