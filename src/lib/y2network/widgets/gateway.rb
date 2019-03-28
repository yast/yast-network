Yast.import "IP"
Yast.import "Popup"
Yast.import "UI"

require "ipaddr"

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class Gateway < CWM::InputField
      # @param route route object to get and store gateway value
      def initialize(route)
        textdomain "network"

        @route = route
      end

      def label
        _("&Gateway")
      end

      def help
        _(
          "<p><b>Gateway</b> defines gateway for given route. Special value here is '-' " \
            "which means do not use gateway for given destination which for non direct " \
            "connections result in reject of connection. For direct destination route is " \
            "created automatically.</p>"
        )
      end

      def opt
        [:hstretch]
      end

      def init
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, Yast::IP.ValidChars + "-")

        self.value = @route.gateway.nil? ? "-" : @route.gateway.to_s
      end

      def validate
        return true if value == "-"

        return true if Yast::IP.Check(value)

        Yast::Popup.Error(_("Gateway IP address is invalid."))
        focus
        false
      end

      def store
        gw = value
        @route.gateway = gw == "-" ? nil : IPAddr.new(gw)
      end
    end
  end
end
