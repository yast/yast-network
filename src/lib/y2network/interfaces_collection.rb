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
require "y2network/interface"
require "y2network/can_be_copied"
require "forwardable"
require "yast2/equatable"

module Y2Network
  # A container for network devices.
  #
  # Objects of this class are able to keep a list of interfaces and perform simple queries
  # on such a list. In the end should implement methods for mass operations over network
  # interfaces
  #
  # @example Finding an interface by its name
  #   interfaces = Y2Network::InterfacesCollection.new([eth0, wlan0])
  #   interfaces.by_name("wlan0") # => wlan0
  #
  # @example Find an interface using its name
  #   iface = collection.by_name("eth0") #=> #<Y2Network::Interface:0x...>
  #
  # @example FIXME (not implemented yet). For the future, we are aiming at this kind of API.
  #   interfaces = Y2Network::InterfacesCollection.new([eth0, wlan0])
  #   interfaces.of_type(:eth).to_a # => [eth0]
  class InterfacesCollection
    extend Forwardable
    include Yast::Logger
    include CanBeCopied
    include Yast2::Equatable

    # @return [Array<Interface>] List of interfaces
    attr_reader :interfaces
    alias_method :to_a, :interfaces

    eql_attr :interfaces

    def_delegators :@interfaces, :each, :push, :<<, :reject!, :map, :flat_map, :any?, :size,
      :select, :find

    # Constructor
    #
    # @param interfaces [Array<Interface>] List of interfaces
    def initialize(interfaces = [])
      @interfaces = interfaces
    end

    def eql_hash
      h = super
      h[:interfaces] = h[:interfaces].sort_by(&:hash) if h.keys.include?(:interfaces)
      h
    end

    # Returns an interface with the given name if present
    #
    # @note It uses the hardware's name as a fallback if interface's name is not set
    #
    # @param name [String] interface name ("eth0", "br1", ...)
    # @return [Interface,nil] Interface with the given name or nil if not found
    def by_name(name)
      interfaces.find do |iface|
        iface_name = iface.name || iface.hardware.name
        iface_name == name
      end
    end

    # Returns an interface with the given hardware busid if present
    #
    # @param busid [String] interface busid ("0.0.0700", "0000:00:19.0", ...)
    # @return [Interface,nil] Interface with the given busid or nil if not found
    def by_busid(busid)
      interfaces.find do |iface|
        iface.hardware && iface.hardware.busid == busid
      end
    end

    # Returns list of interfaces of given type
    #
    # @param type [InterfaceType,String,Symbol] device type or its short name
    # @return [InterfacesCollection] list of found interfaces
    def by_type(type)
      type = InterfaceType.from_short_name(type.to_s) unless type.is_a?(InterfaceType)
      InterfacesCollection.new(interfaces.select { |i| i.type == type })
    end

    # Returns the list of physical interfaces
    #
    # @return [InterfacesCollection] List of physical interfaces
    def physical
      interfaces.select { |i| i.is_a?(PhysicalInterface) }
    end

    # Deletes elements which meet a given condition
    #
    # @return [InterfacesCollection]
    def delete_if(&block)
      interfaces.delete_if(&block)
      self
    end

    # Returns all interfaces names
    #
    # For those interfaces that are renamed, the new and old names are included
    # in the list.
    #
    # @return [Array<String>] List of known interfaces
    def known_names
      @interfaces.map { |i| [i.old_name, i.name] }.flatten.compact
    end

    # @return [String] returns free interface name for given prefix
    def free_name(prefix)
      free_names(prefix, 1).first
    end

    # @return [Array<String>] returns free interface name for given prefix
    def free_names(prefix, count)
      result = []
      # TODO: when switch rubocop use endless range `(0..)`
      (0..100000).each do |i|
        candidate = prefix + i.to_s
        next if by_name(candidate)

        result << candidate
        return result if result.size == count
      end
    end

    # Returns a new collection including elements from both collections
    #
    # @param other [InterfacesCollection] Other interfaces collection
    # @return [InterfacesCollection] New interfaces collection
    def +(other)
      self.class.new(to_a + other.to_a)
    end

    # Returns a new collection including only the elements that are not in the given collection
    #
    # @param other [InterfacesCollection] Other interfaces collection
    # @return [InterfacesCollection] New interfaces collection
    def -(other)
      self.class.new(to_a - other.to_a)
    end
  end
end
