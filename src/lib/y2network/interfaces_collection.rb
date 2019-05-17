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
require "forwardable"

module Y2Network
  # A container for network devices. In the end should implement methods for mass operations over
  # network interfaces like old LanItems::find_dhcp_ifaces.
  #
  # @example Create a new collection
  #   eth0 = Y2Network::Interface.new("eth0")
  #   collection = Y2Network::InterfacesCollection.new(eth0)
  #
  # @example Find an interface using its name
  #   iface = collection.find("eth0") #=> #<Y2Network::Interface:0x...>
  class InterfacesCollection
    # FIXME: Direct access to be replaced to make possible
    # Y2Network::Config.interfaces.eth0
    # Y2Network::Config.interfaces.of_type(:eth)
    # ...
    attr_reader :interfaces

    extend Forwardable
    include Enumerable

    def_delegators :@interfaces, :each, :push, :<<, :reject!

    # Constructor
    #
    # @param interfaces [Array<Interface>] List of interfaces
    def initialize(interfaces = [])
      @interfaces = interfaces
    end

    # Returns a interface with the given name if present
    #
    # @param name [String] Returns the interface with the given name
    # @return [Interface,nil] Interface with the given name or nil if not found
    def by_name(name)
      find { |i| i.name ? i.name == name : i.hardware.name }
    end

    # Add an interface with the given name
    #
    # @param name [String] Interface's name
    def add(name)
      interfaces.push(Interface.new(name))
    end

    # Compares InterfacesCollections
    #
    # @return [Boolean] true when both collections contain only equal interfaces,
    #                   false otherwise
    def ==(other)
      ((interfaces - other.interfaces) | (other.interfaces - interfaces)).empty?
    end

    alias_method :eql?, :==
  end
end
