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
require "y2network/routing_table"
require "y2network/routing"
require "y2network/route"

module Y2Network
  module ConfigReader
    # This class is responsible of importing the AutoYast routing section
    class AutoyastRouting
      # @return [AutoinstProfile::RoutingSection]
      attr_reader :section

      # @param section [AutoinstProfile::RoutingSection]
      def initialize(section)
        @section = section
      end

      # Creates a new {Routing} config from the imported profile routing section
      #
      # @return [Routing] the imported {Routing} config
      def config
        tables = section.routes ? [Y2Network::RoutingTable.new(build_routes)] : []
        Y2Network::Routing.new(tables:       tables,
                               forward_ipv4: !!section.ipv4_forward,
                               forward_ipv6: !!section.ipv6_forward)
      end

    private

      # Build a route given a route section
      #
      # @return [Array<Route>]
      def build_routes
        section.routes.map do |route_section|
          Y2Network::Route.new(to:        route_section.destination || :default,
                               gateway:   route_section.gateway,
                               interface: route_section.device || :any,
                               options:   route_section.extrapara || "")
        end
      end
    end
  end
end
