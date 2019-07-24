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

require "ipaddr"
require "forwardable"

module Y2Network
  # This class represents an IP address
  #
  # The IPAddr from the Ruby standard library drops the host part according to the netmask. The
  # problem is that YaST uses a CIDR-like string, including the host part, to set IPADDR in ifcfg-*
  # files (see man 5 ifcfg for further details).
  #
  # @example IPAddr from standard library behavior
  #  ip = IPAddr.new("192.168.122.1/24")
  #  ip.to_s #=> "192.168.122.0/24"
  #
  # However, what we need is to be able to keep the host part
  #
  # @example IPAddress behaviour
  #   ip = IPAddress.new("192.168.122.1/24")
  #   ip.to_s #=> "192.168.122.1/24"
  #
  # @example IPAddress with no prefix
  #   ip = IPAddress.new("192.168.122.1")
  #   ip.to_s #=> "192.168.122.1"
  class IPAddress
    extend Forwardable

    # @return [IPAddr] IP address
    attr_reader :address
    # @return [Integer] Prefix
    attr_accessor :prefix

    def_delegators :@address, :ipv4?, :ipv6?

    class << self
      def from_string(str)
        address, prefix = str.split("/")
        prefix = prefix.to_i if prefix
        new(address, prefix)
      end
    end

    # Constructor
    #
    # @param address [String] IP address without the prefix
    # @param prefix [Integer] IP prefix (number of bits). If not specified, 32 will be used for IPv4
    #   and 128 for IPv6.
    def initialize(address, prefix = nil)
      @address = IPAddr.new(address)
      @prefix = prefix
    end

    # Returns a string representation of the address
    def to_s
      prefix? ? "#{@address}/#{@prefix}" : @address.to_s
    end

    # Sets the prefix from a netmask
    #
    # @param netmask [String] String representation of the netmask
    def netmask=(netmask)
      self.prefix = IPAddr.new("#{netmask}/#{netmask}").prefix
    end

    # Determines whether two addresses are equivalent
    #
    # @param other [IPAddress] The address to compare with
    # @return [Boolean]
    def ==(other)
      address == other.address && prefix == other.prefix
    end

    alias_method :eql?, :==

    # Determines whether a prefix is defined
    #
    # @return [Boolean]
    def prefix?
      !!@prefix
    end
  end
end
