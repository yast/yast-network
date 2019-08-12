require "cwm/dialog"

module Y2Network
  module Dialogs
    class WirelessWepKeys < CWM::Dialog
      def initialize(settings)
        @settings = settings
      end

      def title
        _("Wireless Keys")
      end

      def help
        _(
          "<p>In this dialog, define your WEP keys used\n" \
            "to encrypt your data before it is transmitted. You can have up to four keys,\n" \
            "although only one key is used to encrypt the data. This is the default key.\n" \
            "The other keys can be used to decrypt data. Usually you have only\n" \
            "one key.</p>"
        ) +
          # Wireless keys dialog help 2/3
          _(
            "<p><b>Key Length</b> defines the bit length of your WEP keys.\n" \
              "Possible are 64 and 128 bit, sometimes also referred to as 40 and 104 bit.\n" \
              "Some older hardware might not be able to handle 128 bit keys, so if your\n" \
              "wireless LAN connection does not establish, you may need to set this\n" \
              "value to 64.</p>"
          ) + ""
      end

      def contents
        HBox(
          HSpacing(5),
          VBox(
            VSpacing(1),
            # Frame label
            Frame(
              _("WEP Keys"),
              HBox(
                HSpacing(3),
                VBox(
                  VSpacing(1),
                  # ComboBox label
                  Left(ComboBox(Id(:length), _("&Key Length"), [64,128])),
                  VSpacing(1),
                  Table(
                    Id(:table),
                    Opt(:notify),
                    Header(
                      # Table header label
                      # Abbreviation of Number
                      _("No."),
                      # Table header label
                      _("Key"),
                      # Table header label
                      Center(_("Default"))
                    ),
                  ),
                  HBox(
                    # PushButton label
                    PushButton(Id(:edit), Yast::Label.EditButton),
                    # PushButton label
                    PushButton(Id(:delete), Yast::Label.DeleteButton),
                    # PushButton label
                    PushButton(Id(:default), _("&Set as Default"))
                  ),
                  VSpacing(1)
                ),
                HSpacing(3)
              )
            ),
            VSpacing(1)
          ),
          HSpacing(5)
        )
      end
    end
  end
end
