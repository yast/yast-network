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

require "forwardable"

module Y2Network
  # Represents a routing table
  #
  # @example Adding routes
  #   table = Y2Network::RoutingTable.new
  #   route = Y2Network::Route.new(to: IPAddr.new("192.168.122.0/24"))
  #   table << route
  #
  # @example Iterating through routes
  #   table.map { |r| r.to } #=> [<IPAddr: IPv4:192.168.122.0/255.255.255.0>]
  class RoutingTable
    extend Forwardable
    include Enumerable

    # @return [Array<Route>] Routes included in the table
    attr_reader :routes

    def_delegator :@routes, :each

    def initialize(routes = [])
      @routes = routes
    end

    # @param routing_table [RoutingTable] Routing table
    # @return [RoutingTable]
    def concat(routing_table)
      @routes.concat(routing_table)
      self
    end

    # Determines whether two routing tables are equal
    #
    # @param other [RoutingTable] Routing table to compare with
    # @return [Boolean]
    def ==(other)
      routes == other.routes
    end

    alias_method :eql?, :==
  end
end
