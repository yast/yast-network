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
    # @return [Symbol] Configuration ID
    attr_reader :id
    # @return [Array<Interface>]
    attr_reader :interfaces
    # @return [Routing]
    attr_reader :routing
    # @return [Symbol] Information source (see {Y2Network::Reader} and {Y2Network::Writer})
    attr_reader :source

    class << self
      # @param source [Symbol] Source to read the configuration from
      def from(source)
        reader = ConfigReader.for(source)
        reader.config
      end
    end

    # Constructor
    #
    # @param id         [Symbol] Configuration ID
    # @param interfaces [Array<Interface>] List of interfaces
    # @param routing    [Routing] Object with routing configuration
    def initialize(id: :system, interfaces:, routing:, source:)
      @id = id
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
  end
end
