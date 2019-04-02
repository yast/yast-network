require "cwm/common_widgets"

module Y2Network
  module Widgets
    class IP4Forwarding < CWM::CheckBox
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def init
        self.value = @config.routing.forward_ipv4
      end

      def store
        @config.routing.forward_ipv4 = value
      end

      def label
        _("Enable &IPv4 Forwarding")
      end

      def help
        _(
          "<p>Enable <b>IPv4 Forwarding</b> (forwarding packets from external networks\n" \
            "to the internal one) if this system is a router.\n" \
            "<b>Important:</b> if the firewall is enabled, allowing forwarding alone is not enough. \n" \
            "You should enable masquerading and/or set at least one redirect rule in the\n" \
            "firewall configuration. Use the YaST firewall module.</p>\n"
        )
      end
    end
  end
end
