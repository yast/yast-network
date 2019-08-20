require "cwm/common_widgets"

module Y2Network
  module Widgets
    # Widget to select EAP mode.
    class WirelessEapMode < CWM::ComboBox
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def init
        self.value = @settings.eap_mode
      end

      def store
        @settings.eap_mode = value
      end

      def label
        _("EAP &Mode")
      end

      # generate event when changed so higher level widget can change content
      # @see Y2Network::Widgets::WirelessEap
      def opt
        [:notify]
      end

      def items
        [
          ["PEAP", _("PEAP")],
          ["TLS", _("TLS")],
          ["TTLS", _("TTLS")]
        ]
      end

      def help
        _(
          "<p>WPA-EAP uses a RADIUS server to authenticate users. There\n" \
            "are different methods in EAP to connect to the server and\n" \
            "perform the authentication, namely TLS, TTLS, and PEAP.</p>\n"
        )
      end
    end
  end
end
