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
        # TODO: original also does not have help
        ""
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
        self.value = interface == :any ? "" : interface
      end

      def store
        interface = value
        @route.interface = interface.empty? ? :any : interface
      end
    end
  end
end
