require "cwm/common_widgets"
Yast.import "NetworkService"

module Y2Network
  module Widgets
    class IP6Forwarding < CWM::CheckBox
      def initialize(config)
        textdomain "network"

        @config = config
      end

      def init
        self.value = @config.routing.forward_ipv6
        disable if Yast::NetworkService.network_manager?
      end

      def store
        @config.routing.forward_ipv6 = value
      end

      def label
        _("Enable I&Pv6 Forwarding")
      end

      def help
        _(
          "<p>Enable <b>IPv6 Forwarding</b> (forwarding packets from external networks\n" \
            "to the internal one) if this system is a router.\n" \
            "<b>Warning:</b> IPv6 forwarding disables IPv6 stateless address\n" \
            "autoconfiguration (SLAAC).</p>"
        )
      end
    end
  end
end
