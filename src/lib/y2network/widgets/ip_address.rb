require "yast"
require "cwm/common_widgets"

Yast.import "LanItems"

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
        self.value = @settings["IPADDR"]
      end

      def store
        @settings["IPADDR"] = value
      end
    end
  end
end

