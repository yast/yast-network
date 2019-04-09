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
require "y2network/interface"
require "y2network/config_writer"
require "y2network/config_reader"

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
  #   route = Y2Network::Route.new(to: :default, interface: :any)
  #   config.routing.tables.first << route
  #   config.write
  class Config
    # @return [Array<Interface>]
    attr_accessor :interfaces
    # FIXME: replacement for old LanItems::Items, should be merged with the above ASAP
    attr_accessor :old_interfaces
    # @return [Routing]
    attr_accessor :routing
    # @return [Symbol] Information source (see {Y2Network::Reader} and {Y2Network::Writer})
    attr_accessor :source

    class << self
      # TODO: move this configs stuff to a separate singleton
      attr_accessor :configs

      # @param source [Symbol] Source to read the configuration from
      # @param opts   [Hash]   Reader options. Check readers documentation to find out
      #                        supported options.
      def from(source, opts = {})
        reader = ConfigReader.for(source, opts)
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
    # @param interfaces [Array<Interface>] List of interfaces
    # @param routing    [Routing] Object with routing configuration
    # @param source     [Symbol] Configuration source
    def initialize(interfaces:, routing:, source:)
      @interfaces = interfaces
      @routing = routing
      @source = source
    end

    # Writes the configuration into the YaST modules
    #
    # @see Y2Network::ConfigWriter
    def write
      Y2Network::ConfigWriter.for(source).write(self)
    end

    # Returns a deep-copy of the configuration
    #
    # @return [Config]
    def copy
      Marshal.load(Marshal.dump(self))
    end

    # Determines whether two configurations are equal
    #
    # @return [Boolean] true if both configurations are equal; false otherwise
    def ==(other)
      source == other.source &&
        ((interfaces - other.interfaces) | (other.interfaces - interfaces)).empty? &&
        routing == other.routing
    end

    alias_method :eql?, :==
  end
end
