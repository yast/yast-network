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
  # This class represents a network route
  class Route
    # @return [IPAddr]
    attr_reader :to
    # @return [Symbol] :local, :multicast, etc.
    attr_reader :type
    # @return [Device]
    attr_reader :device
    # @return [IPAddr,nil]
    attr_reader :source
    # @return [IPAddr,nil]
    attr_reader :via

    def initialize(to, device, via: nil, source: nil, preference: nil, type: :unicast)
      @to = to
      @device = device
      @via = via
      @source = source
      @type = type
      @preference = preference
    end

    # Determines whether it is the default route or not
    #
    # @return [Boolean]
    def default?
      @to.nil?
    end
  end
end
