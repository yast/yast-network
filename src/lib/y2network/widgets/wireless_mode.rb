require "cwm/common_widgets"

module Y2Network
  module Widgets
    class WirelessMode < CWM::ComboBox
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

      def opt
        [:notify, :hstretch]
      end

      def items
        ["Add-hoc", "Managed", "Master"].map { |m| [m, m] }
      end
    end
  end
end
