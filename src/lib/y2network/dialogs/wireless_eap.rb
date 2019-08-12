require "yast"
require "cwm/dialog"
require "y2network/widgets/wireless"

module Y2Network
  module Dialogs
    class WirelessEap < CWM::Dialog
      def initialize(settings)
        @settings = settings

        textdomain = "network"
      end

      def contents
        VBox(
          Label("EAP Dialog")
        )
      end
    end
  end
end
