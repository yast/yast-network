require "yast"
require "cwm/common_widgets"

Yast.import "IP"
Yast.import "Popup"

module Y2Network
  module Widgets
    class IPAddress < CWM::InputField
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("&IP Address")
      end

      def help
        # TODO: write it
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @settings.ip_address
      end

      def store
        @settings.ip_address = value
      end

      def validate
        return true if Yast::IP.Check(value)

        Yast::Popup.Error(_("No valid IP address."))
        focus
        false
      end
    end
  end
end
