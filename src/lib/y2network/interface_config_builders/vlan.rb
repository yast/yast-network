require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    class Vlan < InterfaceConfigBuilder
      def initialize
        super

        self.type = "vlan"
      end

      def etherdevice
        @config["ETHERDEVICE"]
      end

      def etherdevice=(value)
        @config["ETHERDEVICE"] = value
      end

      # @return [Hash<String, String>] returns ordered list of devices that can be used for vlan
      # Keys are ids for #etherdevice and value are label
      def possible_vlans
        res = {}
        # unconfigured devices
        Yast::LanItems.Items.each_value do |lan_item|
          next unless (lan_item["ifcfg"] || "").empty?
          dev_name = lan_item.fetch("hwinfo", {}).fetch("dev_name", "")
          res[dev_name] = dev_name
        end
        # configured devices
        configurations = Yast::NetworkInterfaces.FilterDevices("netcard")
        # TODO: API looks horrible
        Yast::NetworkInterfaces.CardRegex["netcard"].split("|").each do |devtype|
          (configurations[devtype] || {}).each_key do |devname|
            next if Yast::NetworkInterfaces.GetType(devname) == type

            res[devname] = "#{devname} - #{Yast::Ops.get_string(configurations, [devtype, devname, "NAME"], "")}"
          end
        end

        res
      end
    end
  end
end

