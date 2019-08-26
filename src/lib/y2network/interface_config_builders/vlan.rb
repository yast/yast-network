# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    class Vlan < InterfaceConfigBuilder
      def initialize(config: nil)
        super(type: InterfaceType::VLAN, config: config)
      end

      # @return [Integer]
      def vlan_id
        connection_config.vlan_id || 0
      end

      # @param [Integer] value
      def vlan_id=(value)
        connection_config.vlan_id = value
      end

      # @return [String]
      def etherdevice
        connection_config.parent_device
      end

      # @param [String] value
      def etherdevice=(value)
        connection_config.parent_device = value
      end

      # @return [Hash<String, String>] returns ordered list of devices that can be used for vlan
      # Keys are ids for #etherdevice and value are label
      def possible_vlans
        res = {}
        # unconfigured devices
        # TODO: new backend
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
