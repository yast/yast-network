Yast.import "IP"
Yast.import "Popup"

require "ipaddr"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Destination < CWM::InputField
      # @param route [Y2Network::Route] route to modify by widget
      def initialize(route)
        textdomain "network"

        @route = route
      end

      def label
        _("&Destination")
      end

      def help
        # TODO: original also does not have help, so write new one
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, Yast::IP.ValidChars + "-/")
        val = @route.to
        self.value = val == :default ? "-" : (val.to_s + "/" + val.prefix.to_s)
      end

      def validate
        return true if valid_destination?

        Yast::Popup.Error(_("Destination is invalid."))
        focus
        false
      end

      def store
        @route.to = value == "-" ? :default : IPAddr.new(value)
      end

    private

      # Validates user's input obtained from destination field
      def valid_destination?
        destination = value
        return true if destination == "-"

        ip = destination[/^[^\/]+/]
        Yast::IP.Check(ip)
      end
    end
  end
end
