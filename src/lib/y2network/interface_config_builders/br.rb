require "yast"
require "y2network/interface_config_builder"

Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    class Br < InterfaceConfigBuilder
      def initialize
        super(type: "br")
      end

      def bridgable_interfaces
        Yast::LanItems.GetBridgeableInterfaces(name)
      end

      def already_configured?(devices)
        devices.any? do |device|
          next false if Yast::NetworkInterfaces.devmap(device).nil?
          ![nil, "none"].include?(Yast::NetworkInterfaces.devmap(device)["BOOTPROTO"])
        end
      end
    end
  end
end
