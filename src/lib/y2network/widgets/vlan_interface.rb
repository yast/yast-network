require "cwm/common_widgets"

module Y2Network
  module Widgets
    class VlanInterface < CWM::ComboBox
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def label
        _("Real Interface for &VLAN")
      end

      def help
        # TODO: previously not exist, so write it
        ""
      end

      def items
        @config.possible_vlans.map do |key, value|
          [key, value]
        end
      end

      def init
        self.value = @config.etherdevice if @config.etherdevice
      end

      def store
        @config.etherdevice = value
      end
    end
  end
end
