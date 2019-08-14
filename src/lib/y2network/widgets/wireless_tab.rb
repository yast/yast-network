require "yast"
require "cwm/tabs"

# used widgets
require "y2network/widgets/wireless"
require "y2network/widgets/wireless_auth"

module Y2Network
  module Widgets
    class WirelessTab < CWM::Tab
      def initialize(builder)
        textdomain "network"

        @builder = builder
      end

      def label
        _("&Wireless Specific")
      end

      def contents
        VBox(
          VSpacing(0.5),
          Y2Network::Widgets::Wireless.new(@builder),
          VSpacing(0.5),
          Y2Network::Widgets::WirelessAuth.new(@builder),
          VSpacing(0.5),
          # TODO: wireless auth widget
          VStretch()
        )
      end
    end
  end
end

