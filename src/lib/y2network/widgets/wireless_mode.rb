require "cwm/common_widgets"

module Y2Network
  module Widgets
    # Widget to select mode in which wifi card operate
    class WirelessMode < CWM::ComboBox
      # @param config [Y2network::InterfaceConfigBuilder]
      def initialize(config)
        @config = config
        textdomain "network"
      end

      def label
        _("O&perating Mode")
      end

      def init
        self.value = @config.mode
      end

      # notify when mode change as it affect other elements
      def opt
        [:notify, :hstretch]
      end

      def store
        @config.mode = value
      end

      def items
        [
          ["ad-hoc", _("Ad-hoc")],
          ["managed", _("Managed")],
          ["master", _("Master")]
        ]
      end
    end
  end
end
