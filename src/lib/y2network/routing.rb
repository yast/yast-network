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
  # General routing configuration storage (routing tables, forwarding setup, ...)
  class Routing
    # @return [Array<RoutingTable>]
    attr_reader :tables
    # @return [Boolean] whether IPv4 forwarding is enabled
    attr_accessor :forward_ipv4
    # @return [Boolean] whether IPv6 forwarding is enabled
    attr_accessor :forward_ipv6

    def initialize(tables:, forward_ipv4: false, forward_ipv6: false)
      @tables = tables
      @forward_ipv4 = forward_ipv4
      @forward_ipv6 = forward_ipv6
    end

    # Routes in the configuration
    #
    # Convenience method to iterate through the routes in all routing tables.
    #
    # @return [Array<Route>] List of routes which are defined in the configuration
    def routes
      tables.flat_map(&:to_a)
    end

    # Returns the default route
    #
    # @todo Should we implement a `default_routes` which returns an array instead?
    #
    # @return [Route] Returns the first found default route
    def default_route
      routes.find(&:default?)
    end

    # Returns the default routes
    #
    # @return [Array<Route>] Default routes
    def default_routes
      routes.select(&:default?)
    end

    # Remove default routes from routing tables
    def remove_default_routes
      tables.each(&:remove_default_routes)
    end

    # Determines whether two set of routing settings are equal
    #
    # @param other [Routing] Routing settings to compare with
    # @return [Boolean]
    def ==(other)
      forward_ipv4 == other.forward_ipv4 && forward_ipv6 == other.forward_ipv6 &&
        ((tables - other.tables) | (other.tables - tables)).empty?
    end

    alias_method :eql?, :==
  end
end
