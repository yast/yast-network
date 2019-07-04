require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"

module Y2Network
  module InterfaceConfigBuilders
    class Ib < InterfaceConfigBuilder
      def initialize
        super(type: "ib")
      end

      attr_writer :ipoib_mode

      def ipoib_mode
        @ipoib_mode ||= if [nil, ""].include?(@config["IPOIB_MODE"])
          "default"
        else
          @config["IPOIB_MODE"]
        end
      end

      def save
        super

        @config["IPOIB_MODE"] = ipoib_mode == "default" ? nil : ipoib_mode
      end
    end
  end
end
