require "cwm/common_widgets"

module Y2Network
  module Widgets
    class IP4Forwarding < CWM::CheckBox
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def init
        # TODO:
      end


      def store
        # TODO:
      end

      def label
        _("Enable &IPv4 Forwarding")
      end

      def help
        # TODO:
      end
    end
  end
end
