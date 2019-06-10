require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"


module Y2Network
  module InterfaceConfigBuilders
    class Ib < InterfaceConfigBuilder
      def initialize
        super

        self.type = "ib"
      end

      def ipoib_mode
        @ipoib_mode ||= Yast::LanItems.ipoib_mode || "default"
      end

      def ipoib_mode=(value)
        @ipoib_mode = value
      end

      def save
        super

        Yast::LanItems.ipoib_mode = ipoib_mode == "default" ? nil : ipoib_mode
      end
    end
  end
end
