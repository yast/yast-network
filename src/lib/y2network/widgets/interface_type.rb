require "yast"
require "cwm/common_widgets"

Yast.import "NetworkInterfaces"

module Y2Network
  module Widgets
    class InterfaceType < CWM::RadioButtons
      attr_reader :result
      def initialize(default: nil)
        textdomain "network"
        # eth as default
        @default = default || "eth"
      end

      def label
        _("&Device Type")
      end

      def help
        # FIXME: help is not helpful
        _(
          "<p><b>Device Type</b>. Various device types are available, select \n" \
            "one according your needs.</p>"
        )
      end

      def init
        self.value = @default
      end

      def items
        Yast::NetworkInterfaces.GetDeviceTypes.map do |type|
          [type, Yast::NetworkInterfaces.GetDevTypeDescription(type, _long_desc = false)]
        end
      end

      def store
        @result = value
      end
    end
  end
end
