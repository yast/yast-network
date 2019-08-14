require "cwm/common_widgets"

module Y2Network
  module Widgets
    class WirelessAuthMode < CWM::ComboBox
      def initialize(settings)
        @settings = settings
      end

      def init
        self.value = @settings.auth_mode
      end

      def label
        _("&Authentication Mode")
      end

      def opt
        [:hstretch, :notify]
      end

      def items
        [
          ["no-encryption", _("No Encryption")],
          ["open", _("WEP - Open")],
          ["sharedkey", _("WEP - Shared Key")],
          ["wpa-psk", _("WPA-PSK (\"home\")")],
          ["wpa-eap", _("WPA-EAP (\"Enterprise\")")]
        ]
      end

      def help
        # TODO: improve help text, mention all options and security problems with WEP
        "<p>WPA-EAP uses a RADIUS server to authenticate users. There\n" \
        "are different methods in EAP to connect to the server and\n" \
        "perform the authentication, namely TLS, TTLS, and PEAP.</p>\n"
      end

      def store
        @settings.auth_mode = self.value
      end
    end
  end
end
