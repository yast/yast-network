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
require "y2network/dns"
require "ipaddr"
Yast.import "IP"

module Y2Network
  module Autoinst
    # This class is responsible of importing the AutoYast interfaces section
    class InterfacesReader
      # @return [AutoinstProfile::InterfacesSection]
      attr_reader :section

      # @param section [AutoinstProfile::InterfacesSection]
      # TODO: read also udev rules
      def initialize(section)
        @section = section
      end

      # Creates a new {ConnectionConfigsCollection} config from the imported profile interfaces
      # section
      # @note interfaces will be created automatic from connection configs
      #
      # @return [ConnectionConfigsCollection] the imported connections configs
      def config
        configs = @section.interfaces.map do |interface_section|
          config = create_config(interface_section)
          config.bootproto = BootProtocol.from_name(interface_section.bootproto)
          config.name = interface_section.name || interface_section.device # device is just fallback
          if config.bootproto == BootProtocol::STATIC
            # TODO: report if ipaddr missing for static config
            ipaddr = IPAddress.from_string(interface_section.ipaddr)
            # Assign first netmask, as prefixlen has precedence so it will overwrite it
            ipaddr.netmask = interface_section.netmask if interface_section.netmask
            ipaddr.prefix = interface_section.prefixlen.to_i if interface_section.prefixlen
            broadcast = interface_section.broadcast && IPAddress.new(interface_section.broadcast)
            remote = interface_section.remote_ipaddr && IPAddress.new(interface_section.remote_ipaddr)
            config.ip = IPConfig.new(ipaddr, broadcast: broadcast, remote_address: remote)
          end

          config.startmode = Startmode.create(interface_section.startmode) if interface_section.startmode
          config.startmode.priority = interface_section.ifplugd_priority if config.startmode.name == "ifplugd" && interface_section.ifplugd_priority
          config.mtu = interface_section.mtu.to_i if interface_section.mtu
          config.ethtool_options = interface_section.ethtool_options if interface_section.ethtool_options
          config.firewall_zone = interface_section.zone if interface_section.zone

          # TODO: type specific configs
          config
        end

        ConnectionConfigsCollection.new(configs)
      end

    private

      def create_config(interface_section)
        # TODO: autoyast backend for type detector?
        # TODO: TUN/TAP interface missing for autoyast?
        return ConnectionConfig::Bonding.new if interface_section.bonding_slave0 && !interface_section.bonding_slave0.empty?
        return ConnectionConfig::Bridge.new if interface_section.bridge_ports && !interface_section.bridge_ports.empty?
        return ConnectionConfig::Vlan.new if interface_section.etherdevice && !interface_section.etherdevice.empty?
        return ConnectionConfig::Wireless.new if interface_section.wireless_essid && !interface_section.wireless_essid.empty?

        ConnectionConfig::Ethernet.new # TODO: use type detector to read it from sys
      end
    end
  end
end
