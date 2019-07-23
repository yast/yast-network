require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    class Vlan < InterfaceConfigBuilder
      def initialize
        super(type: InterfaceType::VLAN)
      end

      # @return [Integer]
      def vlan_id
        (@config["VLAN_ID"] || "0").to_i
      end

      # @param [Integer] value
      def vlan_id=(value)
        @config["VLAN_ID"] = value.to_s
      end

      # @return [String]
      def etherdevice
        @config["ETHERDEVICE"]
      end

      # @param [String] value
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
