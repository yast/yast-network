require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"

module Y2Network
  module InterfaceConfigBuilders
    class Bond < InterfaceConfigBuilder
      def initialize
        super(type: "bond")
      end

      def bondable_interfaces
        Yast::LanItems.GetBondableInterfaces(name)
      end
    end
  end
end
