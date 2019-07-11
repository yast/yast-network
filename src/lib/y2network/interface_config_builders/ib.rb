require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"

module Y2Network
  module InterfaceConfigBuilders
    class Ib < InterfaceConfigBuilder
      def initialize
        super(type: "ib")
      end

      # @return [String] ipoib mode configuration
      attr_writer :ipoib_mode

      # Returns current value of infiniband mode
      #
      # @return [String] particular mode or "default" when not set
      def ipoib_mode
        @ipoib_mode ||= if [nil, ""].include?(@config["IPOIB_MODE"])
          "default"
        else
          @config["IPOIB_MODE"]
        end
      end

      # (see Y2Network::InterfaceConfigBuilder#save)
      #
      # In case of config builder for Ib interface type it sets infiniband's
      # mode to reasonable default when not set explicitly.
      def save
        super

        @config["IPOIB_MODE"] = ipoib_mode == "default" ? nil : ipoib_mode

        nil
      end
    end
  end
end
