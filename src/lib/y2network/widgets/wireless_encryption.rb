require "cwm/common_widgets"
require "cwm/custom_widget"

module Y2Network
  module Widgets
    class WirelessEncryption < CWM::CustomWidget
      def initialize(settings)
        @settings = settings
        @key_widget = WirelessEncryptionKey.new(settings)
      end

      def contents
        VBox(
          # Translators: input type for a wireless key
          # radio button group label
          Left(Label(_("Key Input Type"))),
          Left(
            HBox(
              # Translators: input type for a wireless key
              RadioButton(Id("passphrase"), _("&Passphrase")),
              HSpacing(1),
              # Translators: input type for a wireless key
              RadioButton(Id("ascii"), _("&ASCII")),
              HSpacing(1),
              # Translators: input type for a wireless key
              # (Hexadecimal)
              RadioButton(Id("hex"), _("&Hexadecimal"))
            )
          ),
          VSpacing(0.2),
          @key_widget
        )
      end

      def enable
        @key_widget.enable
      end

      def disable
        @key_widget.disable
      end
    end

    class WirelessEncryptionKey < CWM::Password
      def initialize(settings)
        @settings = settings
      end

      def label
        _("&Encryption Key")
      end
    end
  end
end
