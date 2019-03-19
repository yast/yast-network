Yast.import "IP"
Yast.import "Popup"
Yast.import "UI"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Gateway < CWM::InputField
      # @param route route object to get and store gateway value
      def initialize(route)
        textdomain "network"
      end

      def label
        _("&Gateway")
      end

      def help
        # TODO: original also does not have help
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        Yast::UI.ChangeWidget(Id(:gateway), :ValidChars, Yast::IP.ValidChars +"-")
        # TODO: init from route object
      end

      def validate
        return true if value == "-"

        return true if Yast::IP.Check(value)

        Yast::Popup.Error(_("Gateway IP address is invalid."))
        focus
        false
      end
    end
  end
end
