require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Gateway < CWM::ComboBox
      # @param route route object to get and store gateway value
      def initialize(route, available_devices)
        textdomain "network"

        @devices = available_devices
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
        # TODO: init from route object
      end
    end
  end
end

