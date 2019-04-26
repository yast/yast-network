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
module Y2Network
  # Network interface.
  #
  # name and hardware attributes should be imutable for the whole life of the object.
  # In other words - we have two configurations 1) system configuration - the one
  # which is currently used by running system and 2) yast configuration - the one which
  # is being modified an will be applied to the system on user's request. name and
  # hardware should always reflect the first configuration bcs it is the only connection /
  # identifier we can use when touching the system (e.g. when setting interfaces down, etc.)
  class Interface
    # @return [String] Device name (eth0, wlan0, etc.)
    attr_accessor :name

    # Constructor
    #
    # @param name [String] Interface name (e.g., "eth0")
    def initialize(name)
      @name = name
    end

    # Determines whether two interfaces are equal
    #
    # @param other [Interface] Interface to compare with
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(Interface)
      name == other.name
    end

    # eql? (hash key equality) should alias ==, see also
    # https://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==
  end
end
