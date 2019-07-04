require "yast"
require "y2network/interface_config_builder"

module Y2Network
  module InterfaceConfigBuilders
    class Dummy < InterfaceConfigBuilder
      def initialize
        super(type: "dummy")
      end

      def save
        super

        @config["INTERFACETYPE"] = "dummy"
      end
    end
  end
end
