require "cwm/common_widgets"

module Y2Network
  module Widgets
    # Widget for WPA "home" password. It is not used for EAP password.
    class WirelessPassword < CWM::Password
      # @param builder [Y2network::InterfaceConfigBuilder]
      def initialize(builder)
        textdomain "network"
        @builder = builder
      end

      def label
        _("Password")
      end

      def init
        self.value = @builder.wpa_psk
      end

      def store
        @builder.wpa_psk = value
      end

      # TODO: write help text

      # TODO: write validation. From man page: You can enter it in hex digits (needs to be exactly
      # 64 digits long) or as passphrase getting hashed (8 to 63 ASCII characters long).
    end
  end
end
