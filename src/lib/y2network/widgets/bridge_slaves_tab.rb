require "yast"
require "cwm/tabs"

# used widgets
require "y2network/widgets/bridge_ports"

module Y2Network
  module Widgets
    class BridgeSlavesTab < CWM::Tab
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("Bridged Devices")
      end

      def contents
        VBox(BridgePorts.new(@settings))
      end
    end
  end
end
