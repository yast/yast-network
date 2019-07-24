require "yast"
require "cwm/common_widgets"

Yast.import "IP"

module Y2Network
  module Widgets
    class RemoteIP < CWM::InputField
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("R&emote IP Address")
      end

      def help
        _(
          "<p>Enter the <b>IP Address</b> (for example: <tt>192.168.100.99</tt>) for your computer, and the \n" \
          " <b>Remote IP Address</b> (for example: <tt>192.168.100.254</tt>)\n" \
          "for your peer.</p>\n"
        )
      end

      def init
        self.value = @settings.remote_ip
      end

      def store
        @settings.remote_ip = value
      end

      def validate
        return true if Yast::IP.Check(value)

        Yast::Popup.Error(_("The remote IP address is invalid.") + "\n" + Yast::IP.Valid4)
      end
    end
  end
end
