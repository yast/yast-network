Yast.import "IP"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Destination < CWM::InputField
     # @param route route object to get and store netmask value
     # TODO: I expect it will be useful on multiple places, so we need find way how to store it
      def initialize(route)
        textdomain "network"
      end

      def label
        _("&Destination")
      end

      def help
        # TODO: original also does not have help
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, Yast::IP.ValidChars +"-/")
        # TODO: init from route object
      end

      def validate
        return true if valid_destination?

        Yast::Popup.Error(_("Destination is invalid."))
        focus
        false
      end

    private

      # Validates user's input obtained from destination field
      def valid_destination?
        destination = value
        return true if destination == "default"

        ip = destination[/^[^/]+/]
        Yast::IP.Check(ip)
      end
    end
  end
end
