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

module Y2Network
  # This class is responsible for creating a bridge configuration for
  # virtualization from the interfaces that are connected and bridgeable.
  class VirtualizationConfig
    include Yast::Logger
    # @return [Y2Network::Config]
    attr_reader :config

    # Constructor
    #
    # @param config [Y2Network::Config]
    def initialize(config)
      @config = config
    end

    # Obtains the interfaces that are candidates for being bridgeable
    #
    # @return [Array<Y2Network::Interface]
    def bridgeable_candidates
      builder = Y2Network::InterfaceConfigBuilder.for("br")
      builder.name = config.interfaces.free_name("br")

      config.interfaces.select { |i| connected_and_bridgeable?(builder, i) }
    end

    # Iterates over the bridgeable candidates creating a bridge for each of
    # them. The connection is copied to the bridge when exist and the
    # interface is added as a bridge port
    #
    # @return [Boolean] true when a new bridge was created
    def create
      return false if bridgeable_candidates.empty?

      bridgeable_candidates.each do |interface|
        bridge_builder = bridge_builder_for(interface)

        connection = config.connections.by_name(interface.name)
        # The configuration of the connection being slaved is copied to the
        # bridge when exist
        bridge_builder.configure_from(connection) if connection

        builder = Y2Network::InterfaceConfigBuilder.for(interface.type, config: connection)
        builder.name = interface.name
        builder.configure_as_slave
        builder.save

        # It adds the connection and the virtual interface
        bridge_builder.save

        # Move routes from the port member to the bridge (bsc#903889)
        move_routes(builder.name, bridge_builder.name)
      end

      true
    end

  private

    # Adds a new interface with the given name
    def add_device_to_routing(name)
      return if !config
      return if config.interfaces.any? { |i| i.name == name }

      config.interfaces << Y2Network::Interface.new(name)
    end

    # Assigns all the routes from one interface to another
    #
    # @param from [String] interface belonging the routes to be moved
    # @param to [String] target interface
    def move_routes(from, to)
      return unless config&.routing

      routing = config.routing
      add_device_to_routing(to)
      target_interface = config.interfaces.by_name(to)
      return unless target_interface

      routing.routes.select { |r| r.interface && r.interface.name == from }
        .each { |r| r.interface = target_interface }
    end

    # Convenience method that returns true if the interface given is connected
    # and can be added as a bridge port.
    #
    # @param bridge_builder [Y2Network::InterfaceConfigBuilders::Bridge]
    # @param interface [Y2Network::Interface] bridge candidate member
    # @return [Boolean] true if it is connected and bridgeable
    def connected_and_bridgeable?(bridge_builder, interface)
      if !bridge_builder.bridgeable_interfaces.map(&:name).include?(interface.name)
        log.info "The interface #{interface.name} cannot be proposed as bridge."
        return false
      end

      unless interface.connected?
        log.warn("The interface #{interface.inspect} does not have link")
        return false
      end

      if interface.type.wireless?
        log.warn("Not proposing WLAN interface for lan item: #{interface.inspect}")
        return false
      end
      true
    end

    # Convenience method for initializing a new bridge builder with the
    # interface given as a port member
    #
    # @param interface [Y2Network::Interface]
    def bridge_builder_for(interface)
      bridge_builder = Y2Network::InterfaceConfigBuilder.for("br")
      bridge_builder.name = config.interfaces.free_name("br")

      bridge_builder.ports = [interface.name]
      bridge_builder.startmode = "auto"
      bridge_builder.boot_protocol = "dhcp"

      bridge_builder
    end
  end
end
