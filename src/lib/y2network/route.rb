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
    # @return [IPAddr,:default] Destination; :default if it is the default route
    attr_reader :to
    # @return [Interface,:any] Interface to associate the route to; :any if no interface is given
    attr_reader :interface
    # @return [IPAddr,nil] Source IP address ('src' in ip route)
    attr_reader :source
    # @return [IPAddr,nil] Gateway IP address ('via' in ip route)
    attr_reader :gateway
    # @return [String] Additional options
    attr_reader :options

    # @param to        [IPAddr,:default] Destination
    # @param interface [Interface,:any] Interface to associate the root to
    # @param gateway   [IPAddr,nil] Gateway IP
    # @param source    [IPAddr,nil] Source IP
    # @param options   [String] Additional options
    def initialize(to: :default, interface: :any, gateway: nil, source: nil, options: "")
      @to = to
      @interface = interface
      @gateway = gateway
      @source = source
      @options = options
    end

    # Determines whether it is the default route or not
    #
    # @return [Boolean]
    def default?
      to == :default
    end
  end
end
