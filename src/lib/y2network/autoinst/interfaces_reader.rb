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
          # TODO: read it from section
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
