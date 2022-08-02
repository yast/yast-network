# Copyright (c) [2022] SUSE LLC
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

module Y2Network
  # This class is responsible for creating the connection configuration for a
  # given FCoE storage only device
  class FcoeConnGenerator
    include Yast::Logger
    # @return [Y2Network::Config]
    attr_reader :config

    def initialize(config)
      @config = config
    end

    # @param card [Hash] a hash with all the information about a network interface
    def update_connections_for(card)
      update_parent_connection_for(card)
      update_vlan_connection_for(card)
    end

  private

    # Adds or modifies the network configuration for the FCoE VLAN parent device
    #
    # @param card [Hash] a hash with all the information about a network interface
    def update_parent_connection_for(card)
      name = card.fetch("dev_name", "")
      conn = config.connections.by_name(name)
      builder = Y2Network::InterfaceConfigBuilder.for("eth", config: conn)
      builder.name = name
      builder.startmode = "nfsroot"
      if conn.nil?
        builder.boot_protocol = "static"
        config = builder.connection_config
        # FIXME: we should delegate this method to the connection_config
        config.description = card.fetch("device", "") if config
      end
      builder.save
    end

    # Adds the network configuration for the FCoE VLAN interface
    #
    # @param card [Hash] a hash with all the information about a network interface
    def update_vlan_connection_for(card)
      dev_name = card.fetch("dev_name", "")
      vid = card.fetch("vlan_interface", "0").to_i
      return if vid == 0

      vlan_builder = Y2Network::InterfaceConfigBuilder.for("vlan")
      vlan_builder.name = card.fetch("fcoe_vlan")
      vlan_builder.etherdevice = dev_name
      vlan_builder.boot_protocol = "static"
      vlan_builder.startmode = "nfsroot"
      vlan_builder.vlan_id = vid
      vlan_builder.save
    end
  end
end
