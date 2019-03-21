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

    def initialize(tables:)
      @tables = tables
    end

    # Checks whether IPv4 forwarding is enabled
    def forward_ipv4?
    end

    # Checks whether IPv6 forwarding is enabled
    def forward_ipv6?
    end

    # Routes in the configuration
    #
    # Convenience method to iterate through the routes in all routing tables.
    #
    # @return [Array<Route>] List of routes which are defined in the configuration
    def routes
      tables.flat_map(&:to_a)
    end
  end
end
