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
require "y2network/interface_type"
require "y2network/type_detector"

Yast.import "NetworkInterfaces"

module Y2Network
  module Sysconfig
    # Detects type of given interface. New implementation of what was in
    # @see Yast::NetworkInterfaces.GetType
    class TypeDetector < Y2Network::TypeDetector
      class << self
      private
        KEY_TO_TYPE = {
          "ETHERDEVICE" => InterfaceType::VLAN,
          "WIRELESS_MODE" => InterfaceType::WIRELESS,
          "MODEM_DEVICE" => InterfaceType::PPP
        }.freeze

        # Checks wheter iface type can be recognized by interface configuration
        def type_by_config(iface)
          devmap = devmap(iface)
          return nil if !devmap

          type_by_key_value(devmap) ||
            type_by_key_existence(devmap) ||
            type_from_interfacetype(devmap) ||
            type_by_name(iface)
        end

        # Provides interface's sysconfig configuration
        #
        # @return [Hash{String => Object}] parsed configuration
        def devmap(iface)
          scr_path = ".network.value.\"#{iface}\""
          values = Yast::SCR.Dir(Yast::Path.new(scr_path))

          # provide configuration in canonicalized format
          devmap = Yast::NetworkInterfaces.generate_config(scr_path, values)

          log.info("TypeDetector: #{iface} configuration: #{devmap.inspect}")

          devmap
        end

        # Detects interface type according to type specific option
        #
        # @param devmap [Hash<String, String>] a sysconfig configuration of an interface
        #
        # @return [Y2Network::InterfaceType, nil] particular type if recognized, nil otherwise
        def type_by_key_existence(devmap)
          key = KEY_TO_TYPE.keys.find { |k| devmap.include?(k) }
          return KEY_TO_TYPE[key] if key

          nil
        end

        # Detects interface type according to type specific option and its value
        #
        # @param devmap [Hash<String, String>] a sysconfig configuration of an interface
        #
        # @return [Y2Network::InterfaceType, nil] particular type if recognized, nil otherwise
        def type_by_key_value(devmap)
          return InterfaceType::BONDING if devmap["BONDING_MASTER"] == "yes"
          return InterfaceType::BRIDGE if devmap["BRIDGE"] == "yes"
          return InterfaceType::WIRELESS if devmap["WIRELESS"] == "yes"
          return InterfaceType.from_short_name(devmap["TUNNEL"]) if devmap["TUNNEL"]

          # in relation to original implementation ommited ENCAP option which leads to isdn
          # and PPPMODE which leads to ppp. Neither of this type has been handled as
          # "netcard" - see Yast::NetworkInterfaces for details

          nil
        end

        # Detects interface type according to sysconfig's INTERFACETYPE option
        #
        # @param devmap [Hash<String, String>] a sysconfig configuration of an interface
        #
        # @return [Y2Network::InterfaceType, nil] type according to INTERFACETYPE option
        #                                    value if recognized, nil otherwise
        def type_from_interfacetype(devmap)
          return InterfaceType::from_short_name(devmap["INTERFACETYPE"]) if devmap["INTERFACETYPE"]
          nil
        end

        # Distinguishes interface type by its name
        #
        # The only case should be loopback device with special name (in sysconfig) "lo"
        #
        # @return [Y2Network::InterfaceType, nil] InterfaceType::LO or nil if not loopback
        def type_by_name(iface)
          InterfaceType::LO if iface == "lo"
          nil
        end
      end
    end
  end
end
