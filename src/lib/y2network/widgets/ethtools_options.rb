require "yast"
require "cwm/common_widgets"

Yast.import "LanItems"

module Y2Network
  module Widgets
    class EthtoolsOptions < CWM::InputField
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("Ethtool Options")
      end

      def help
        _(
          "<p>If you specify options via <b>Ethtool options</b>, ifup will call ethtool with these options.</p>\n"
        )
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @settings["ETHTOOL_OPTIONS"]
      end

      def store
        @settings["ETHTOOL_OPTIONS"] = value
      end
    end
  end
end
