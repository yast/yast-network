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
  #   iface = collection.by_name("eth0") #=> #<Y2Network::Interface:0x...>
  class InterfacesCollection
    # Objects of this class are able to keep a list of interfaces and perform simple queries
    # on such a list.
    #
    # @example Finding an interface by its name
    #   interfaces = Y2Network::InterfacesCollection.new([eth0, wlan0])
    #   interfaces.by_name("wlan0") # => wlan0
    #
    # @example FIXME (not implemented yet). For the future, we are aiming at this kind of API.
    #   interfaces = Y2Network::InterfacesCollection.new([eth0, wlan0])
    #   interfaces.of_type(:eth).to_a # => [eth0]

    extend Forwardable

    # @return [Array<Interface>] List of interfaces
    attr_reader :interfaces
    alias_method :to_a, :interfaces

    def_delegators :@interfaces, :each, :push, :<<, :reject!, :map, :flat_map, :any?

    # Constructor
    #
    # @param interfaces [Array<Interface>] List of interfaces
    def initialize(interfaces = [])
      @interfaces = interfaces
    end

    # Returns an interface with the given name if present
    #
    # @todo It uses the hardware's name as a fallback if interface's name is not set
    #
    # @param name [String] Returns the interface with the given name
    # @return [Interface,nil] Interface with the given name or nil if not found
    def by_name(name)
      interfaces.find do |iface|
        iface_name = iface.name ? iface.name : iface.hwinfo.name
        iface_name == name
      end
    end

    # Deletes elements which meet a given condition
    #
    # @return [InterfacesCollection]
    def delete_if(&block)
      interfaces.delete_if(&block)
      self
    end

    # Compares InterfacesCollections
    #
    # @return [Boolean] true when both collections contain only equal interfaces,
    #                   false otherwise
    def ==(other)
      ((interfaces - other.interfaces) + (other.interfaces - interfaces)).empty?
    end

    alias_method :eql?, :==
  end
end
