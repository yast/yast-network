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
  # The problem with the IPAddr from the Ruby standard library, is that it drops
  # the host part according to the netmask.
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
  class IPAddress
    extend Forwardable

    # @return [IPAddr] IP address
    attr_reader :address
    # @return [Integer] Prefix
    attr_reader :prefix

    def_delegators :@address, :ipv4?, :ipv6?

    class << self
      def from_string(str)
        address, prefix = str.split("/")
        prefix = prefix.to_i if prefix
        new(address, prefix)
      end
    end

    # @return [Integer] IPv4 address default prefix
    IPV4_DEFAULT_PREFIX = 32
    # @return [Integer] IPv6 address default prefix
    IPV6_DEFAULT_PREFIX = 128

    # Constructor
    #
    # @param address [String] IP address without the prefix
    # @param prefix [Integer] IP prefix (number of bits). If not specified, 32 will be used for IPv4
    #   and 128 for IPv6.
    def initialize(address, prefix = nil)
      @address = IPAddr.new(address)
      @prefix = prefix
      @prefix ||= @address.ipv4? ? IPV4_DEFAULT_PREFIX : IPV6_DEFAULT_PREFIX
    end

    # Returns a string representation of the address
    def to_s
      host? ? @address.to_s : "#{@address}/#{@prefix}"
    end

  private

    # Determines whether it is a host address
    #
    # @return [Boolean]
    def host?
      (ipv4? && prefix == IPV4_DEFAULT_PREFIX) && (ipv6? && prefix == IPV6_DEFAULT_PREFIX)
    end
  end
end
