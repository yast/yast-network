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
require "forwardable"

module Y2Network
  # A container for connection configurations objects.
  #
  # @example Create a new collection
  #   eth0 = Y2Network::ConnectionConfig::Ethernet.new
  #   collection = Y2Network::ConnectionConfigsCollection.new([eth0])
  #
  # @example Find a connection config using its name
  #   config = collection.by_name("eth0") #=> #<Y2Network::ConnectionConfig::Ethernet:0x...>
  class ConnectionConfigsCollection
    extend Forwardable
    include Yast::Logger

    attr_reader :connection_configs
    alias_method :to_a, :connection_configs

    def_delegators :@connection_configs, :each, :find, :push, :<<, :reject!, :map, :flat_map, :any?, :size

    # Constructor
    #
    # @param connection_configs [Array<ConnectionConfig>] List of connection configurations
    def initialize(connection_configs = [])
      @connection_configs = connection_configs
    end

    # Returns a connection configuration with the given name if present
    #
    # @param name [String] Connection name
    # @return [ConnectionConfig::Base,nil] Connection config with the given name or nil if not found
    def by_name(name)
      connection_configs.find { |c| c.name == name }
    end

    # Returns connection configurations which are associated to the given interface
    #
    # @param interface_name [String] Interface name
    # @return [Array<ConnectionConfig::Base>] Associated connection configs
    def by_interface(interface_name)
      connection_configs.select { |c| c.interface == interface_name }
    end

    # Adds or updates a connection configuration
    #
    # @note It uses the name to do the matching.
    #
    # @param connection_config [ConnectionConfig::Base] New connection configuration object
    def add_or_update(connection_config)
      idx = connection_configs.find_index { |c| c.name == connection_config.name }
      if idx
        connection_configs[idx] = connection_config
      else
        connection_configs << connection_config
      end
    end

    # Removes a connection configuration
    #
    # @note It uses the name to do the matching.
    #
    # @param connection_config [ConnectionConfig::Base,String] Connection configuration object or name
    def remove(connection_config)
      name = connection_config.respond_to?(:name) ? connection_config.name : connection_config
      connection_configs.reject! { |c| c.name == name }
    end

    # Compares ConnectionConfigsCollection
    #
    # @return [Boolean] true when both collections contain only equal connections,
    #                   false otherwise
    def ==(other)
      ((connection_configs - other.connection_configs) + (other.connection_configs - connection_configs)).empty?
    end

    alias_method :eql?, :==
  end
end
