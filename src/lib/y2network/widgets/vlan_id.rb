require "cwm/common_widgets"

module Y2Network
  module Widgets
    class VlanID < CWM::IntField
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def label
        _("VLAN ID")
      end

      def help
        # TODO: previously not exist, so write it
        ""
      end

      def init
        self.value = @config.vlan_id
      end

      def store
        @config.vlan_id = value.to_s
      end

      def minimum
        0
      end

      def maximum
        9999
      end
    end
  end
end
