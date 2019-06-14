require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"

module Y2Network
  module InterfaceConfigBuilders
    class Bridge < InterfaceConfigBuilder
      def initialize
        super(type: "bridge")
      end

      def bridgable_interfaces
        Yast::LanItems.GetBridgeableInterfaces(name)
      end

      def already_configured?(devices)
        configurations = Yast::NetworkInterfaces.FilterDevices("netcard")
        netcard_types = (Yast::NetworkInterfaces.CardRegex["netcard"] || "").split("|")

        confs = netcard_types.reduce([]) do |res, devtype|
          res.concat((configurations[devtype] || {}).keys)
        end

        devices.each do |device|
          next if !confs.include?(device)

          dev_type = Yast::NetworkInterfaces.GetType(device)
          ifcfg_conf = configurations[dev_type][device]

          next if ifcfg_conf["BOOTPROTO"] == "none"

          return true
        end

        false
      end
    end
  end
end
