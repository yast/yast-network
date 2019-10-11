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

module Y2Network
  # This class represents the supported IPoIB transport modes.
  # @see https://www.kernel.org/doc/html/latest/infiniband/ipoib.html
  #      IP over InfiniBand
  class IpoibMode
    class << self
      # Returns all the existing modes
      #
      # @return [Array<IpoibMode>]
      def all
        @all ||= IpoibMode.constants
          .map { |c| IpoibMode.const_get(c) }
          .select { |c| c.is_a?(IpoibMode) }
      end

      # Returns the transport mode with a given name
      #
      # @param name [String]
      # @return [IpoibMode,nil] Ipoib mode or nil if not found
      def from_name(name)
        all.find { |t| t.name == name }
      end
    end

    # @return [String] Returns mode name
    attr_reader :name

    # Constructor
    #
    # @param name [String] mode name
    def initialize(name)
      @name = name
    end

    # Determines whether two objects are equivalent
    #
    # They are equal when they refer to the same IPoIB mode (through the name).
    #
    # @param other [IpoibMode] IPoIB mode to compare with
    # @return [Boolean]
    def ==(other)
      name == other.name
    end

    alias_method :eql?, :==

    DATAGRAM = new("datagram")
    CONNECTED = new("connected")
    # Not a mode at all but the default value that will be choose by the IB
    # driver (bnc#1086454)
    DEFAULT = new("")
  end
end
