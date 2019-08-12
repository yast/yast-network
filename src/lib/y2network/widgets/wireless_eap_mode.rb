require "cwm/common_widgets"

module Y2Network
  module Widgets
    class WirelessEapMode < CWM::ComboBox
      def initialize(settings)
      end

      def help
        "<p>WPA-EAP uses a RADIUS server to authenticate users. There\n" \
        "are different methods in EAP to connect to the server and\n" \
        "perform the authentication, namely TLS, TTLS, and PEAP.</p>\n"
      end
    end
  end
end

