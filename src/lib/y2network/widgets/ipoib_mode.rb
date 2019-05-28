require "yast"
require "cwm/common_widgets"

Yast.import "LanItems"

module Y2Network
  module Widgets
    class IPoIBMode < CWM::RadioButtons
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def items
        # ipoib_modes contains known IPoIB modes, "default" is place holder for
        # "do not set anything explicitly -> driver will choose"
        # translators: a possible value for: IPoIB device mode
        [
          ["default", _("default")],
          ["connected", _("connected")],
          ["datagram", _("datagram")]
        ]
      end

      def label
        _("IPoIB Device Mode")
      end

      def opt
        [:hstretch]
      end

      def init
        # TODO: not direct access to LanItems
        ipoib_mode = Yast::LanItems.ipoib_mode || "default"

        self.value = ipoib_mode
      end

      def store
        # TODO: not direct access to LanItems
        Yast::LanItems.ipoib_mode = value == "default" ? nil : value
      end
    end
  end
end

