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
  module Presenters
    # This class converts a route into a hash to be used in an AutoYaST profile
    class RouteProfile
      def initialize(route)
        @route = route
      end

      # Returns a representation of the route to use in an AutoYaST profile
      #
      # @return [Hash]
      def to_profile
        hash = {
          "destination" => destination(route),
          "device"      => device(route),
          "gateway"     => gateway(route),
          "extrapara"   => extrapara(route)
        }
        hash["source"] = route.source.to_s if route.source
        hash
      end

    private

      # @return [Y2Network::Route]
      attr_reader :route

      # Returns the destination for the given route
      #
      # @param route [Route] Route to get the destination from
      # @return [String] Route destination
      def destination(route)
        return "default" if route.to == :default
        [route.to.to_s, route.to.prefix].join("/")
      end

      # Returns the device (interface) for the given route
      #
      # @param route [Route] Route to get the device from
      # @return [String] Device name
      def device(route)
        return "-" unless route.interface.respond_to?(:name)
        route.interface.name
      end

      # Returns the gateway for the given route
      #
      # @param route [Route] Route to get the gateway from
      # @return [String] Gateway address
      def gateway(route)
        return "-" unless route.gateway
        route.gateway.to_s
      end

      # Returns the extra parameters for the given route
      #
      # @param route [Route] Route to get the options from
      # @return [String] Extra parameters
      def extrapara(route)
        route.options
      end
    end
  end
end
