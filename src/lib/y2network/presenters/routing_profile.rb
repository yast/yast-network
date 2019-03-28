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

require "y2network/presenters/route_profile"

module Y2Network
  module Presenters
    # This class converts a routing configuration object into a hash to be used
    # in an AutoYaST profile
    class RoutingProfile
      # Constructor
      #
      # @param routing [Y2Network::Routing] Routing configuration
      def initialize(routing)
        @routing = routing
      end

      # Returns a representation to use in an AutoYaST profile
      #
      # @return [Hash]
      def to_profile
        {
          "ipv4_forward" => routing.forward_ipv4,
          "ipv6_forward" => routing.forward_ipv6,
          "routes"       => routing.routes.map { |r| route_to_profile(r) }
        }
      end

    private

      # @return [Y2Network::Routing] Routing configuration
      attr_reader :routing

      # Return a representation of a route to use in an AutoYaST profile
      #
      # @todo It might be implemented in a separate class
      def route_to_profile(route)
        Y2Network::Presenters::RouteProfile.new(route).to_profile
      end
    end
  end
end
