require "cwm/common_widgets"

module Y2Network
  module Widgets
    class WirelessEapMode < CWM::ComboBox
      def initialize(settings)
        @settings = settings
      end

      def init
        self.value = @settings.eap_mode
      end

      def label
        _("EAP &Mode")
      end

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
        "<p>WPA-EAP uses a RADIUS server to authenticate users. There\n" \
        "are different methods in EAP to connect to the server and\n" \
        "perform the authentication, namely TLS, TTLS, and PEAP.</p>\n"
      end
    end
  end
end

