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
require "y2network/config_writer"
require "y2network/config_reader"
require "y2network/routing"
require "y2network/dns"
require "y2network/interfaces_collection"
require "y2network/connection_configs_collection"
require "y2network/physical_interface"
require "y2network/can_be_copied"

module Y2Network
  # This class represents the current network configuration including interfaces,
  # routes, etc.
  #
  # @example Reading from wicked
  #   config = Y2Network::Config.from(:sysconfig)
  #   config.interfaces.map(&:name) #=> ["lo", eth0", "wlan0"]
  #
  # @example Adding a default route to the first routing table
  #   config = Y2Network::Config.from(:sysconfig)
  #   route = Y2Network::Route.new(to: :default)
  #   config.routing.tables.first << route
  #   config.write
  class Config
    include CanBeCopied
    include Yast::Logger

    # @return [InterfacesCollection]
    attr_accessor :interfaces
    # @return [ConnectionConfigsCollection]
    attr_accessor :connections
    # @return [Routing] Routing configuration
    attr_accessor :routing
    # @return [DNS] DNS configuration
    attr_accessor :dns
    # @return [Array<Driver>] Available drivers
    attr_accessor :drivers
    # @return [Symbol] Information source (see {Y2Network::Reader} and {Y2Network::Writer})
    attr_accessor :source

    class << self
      # @param source [Symbol] Source to read the configuration from
      # @param opts   [Array<Object>] Reader options. Check readers documentation to find out
      #   supported options.
      def from(source, *opts)
        reader = ConfigReader.for(source, *opts)
        reader.config
      end

      # Adds the configuration to the register
      #
      # @param id     [Symbol] Configuration ID
      # @param config [Y2Network::Config] Network configuration
      def add(id, config)
        configs[id] = config
      end

      # Finds the configuration in the register
      #
      # @param id [Symbol] Configuration ID
      # @return [Config,nil] Configuration with the given ID or nil if not found
      def find(id)
        configs[id]
      end

      # Resets the configuration register
      def reset
        configs.clear
      end

    private

      # Configuration register
      def configs
        @configs ||= {}
      end
    end

    # Constructor
    #
    # @param interfaces  [InterfacesCollection] List of interfaces
    # @param connections [ConnectionConfigsCollection] List of connection configurations
    # @param routing     [Routing] Object with routing configuration
    # @param dns         [DNS] Object with DNS configuration
    # @param source      [Symbol] Configuration source
    # @param drivers     [Array<Driver>] List of available drivers
    def initialize(interfaces: InterfacesCollection.new, connections: ConnectionConfigsCollection.new,
      routing: Routing.new, dns: DNS.new, drivers: [], source:)
      @interfaces = interfaces
      @connections = connections
      @drivers = drivers
      @routing = routing
      @dns = dns
      @source = source
    end

    # Writes the configuration into the YaST modules
    #
    # Writes only changes against original configuration if the original configuration
    # is provided
    #
    # @param original [Y2Network::Config] configuration used for detecting changes
    # @param target   [Symbol] Target to write the configuration to (:sysconfig)
    #
    # @see Y2Network::ConfigWriter
    def write(original: nil, target: nil)
      target ||= source
      Y2Network::ConfigWriter.for(target).write(self, original)
    end

    # Determines whether two configurations are equal
    #
    # @return [Boolean] true if both configurations are equal; false otherwise
    def ==(other)
      source == other.source && interfaces == other.interfaces &&
        routing == other.routing && dns == other.dns && connections == other.connections
    end

    # Renames a given interface and the associated connections
    #
    # @param old_name  [String] Old interface's name
    # @param new_name  [String] New interface's name
    # @param mechanism [Symbol] Property to base the rename on (:mac or :bus_id)
    def rename_interface(old_name, new_name, mechanism)
      log.info "Renaming #{old_name.inspect} to #{new_name.inspect} using #{mechanism.inspect}"
      interface = interfaces.by_name(old_name || new_name)
      interface.rename(new_name, mechanism)
      return unless old_name # do not modify configurations if it is just renaming mechanism
      connections.by_interface(old_name).each do |connection|
        connection.interface = new_name
        rename_dependencies(old_name, new_name, connection)
      end
      dns.dhcp_hostname = new_name if dns.dhcp_hostname == old_name
    end

    # deletes interface and all its config. If interface is physical,
    # it is not removed as we cannot remove physical interface.
    #
    # @param name [String] Interface's name
    def delete_interface(name)
      delete_dependents(name)

      connections.reject! { |c| c.interface == name }
      # do not use no longer existing device name
      dns.dhcp_hostname = :none if dns.dhcp_hostname == name
      interface = interfaces.by_name(name)
      return if interface.is_a?(PhysicalInterface) && interface.present?

      interfaces.reject! { |i| i.name == name }
    end

    # Adds or update a connection config
    #
    # If the interface which is associated to does not exist (because it is a virtual one or it is
    # not present), it gets added.
    def add_or_update_connection_config(connection_config)
      log.info "add_update connection config #{connection_config.inspect}"
      connections.add_or_update(connection_config)
      interface = interfaces.by_name(connection_config.interface)
      return if interface
      log.info "Creating new interface"
      interfaces << Interface.from_connection(connection_config)
    end

    # Returns the candidate drivers for a given interface
    #
    # @return [Array<Driver>]
    def drivers_for_interface(name)
      interface = interfaces.by_name(name)
      names = interface.drivers.map(&:name)
      names << interface.custom_driver if interface.custom_driver && !names.include?(interface.custom_driver)
      drivers.select { |d| names.include?(d.name) }
    end

    # Adds or update a driver
    #
    # @param new_driver [Driver] Driver to add or update
    def add_or_update_driver(new_driver)
      idx = drivers.find_index { |d| d.name == new_driver.name }
      if idx
        drivers[idx] = new_driver
      else
        drivers << new_driver
      end
    end

    # Determines whether a given interface is configured or not
    #
    # An interface is considered as configured when it has an associated collection.
    #
    # @param iface_name [String] Interface's name
    # @return [Boolean]
    def configured_interface?(iface_name)
      return false if iface_name.nil? || iface_name.empty?
      !connections.by_interface(iface_name).empty?
    end

    # @note does not work recursively. So for delete it needs to be called for all modified vlans.
    # @return [ConnectionConfigsCollection] returns collection of interfaces that needs
    #   to be modified or deleted if `connection_config` is deleted or renamed
    def connections_to_modify(connection_config)
      result = []
      bond_bridge = connection_config.find_master(connections)
      result << bond_bridge if bond_bridge
      vlans = connections.to_a.select { |c| c.type.vlan? && c.parent_device == connection_config.name }
      result.concat(vlans)
      ConnectionConfigsCollection.new(result)
    end

    alias_method :eql?, :==

  private

    def delete_dependents(name)
      connection = connections.by_name(name)

      to_modify = connections_to_modify(connection)
      to_modify.each do |dependency|
        case dependency.type
        when InterfaceType::BRIDGE
          dependency.ports.delete(name)
        when InterfaceType::BONDING
          dependency.slaves.delete(name)
        when InterfaceType::VLAN
          delete_interface(dependency.interface)
        else
          raise "Unexpected type of interface to modify #{dependency.inspect}"
        end
      end
    end

    def rename_dependencies(old_name, new_name, connection)
      to_modify = connections_to_modify(connection)
      to_modify.each do |dependency|
        case dependency.type
        when InterfaceType::BRIDGE
          dependency.ports.map! { |e| e == old_name ? new_name : e }
        when InterfaceType::BONDING
          dependency.slaves.map! { |e| e == old_name ? new_name : e }
        when InterfaceType::VLAN
          dependency.parent_device = new_name
        else
          raise "Unexpected type of interface to modify #{dependency.inspect}"
        end
      end
    end
  end
end
