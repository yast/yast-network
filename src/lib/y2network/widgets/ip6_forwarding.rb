require "cwm/common_widgets"

module Y2Network
  module Widgets
    class IP6Forwarding < CWM::CheckBox
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def init
        # TODO: define when config is final
      end

      def store
        # TODO: define when config is final
      end

      def label
        _("Enable I&Pv6 Forwarding")
      end

      def help
        # TODO: define when config is final
      end
    end
  end
end
