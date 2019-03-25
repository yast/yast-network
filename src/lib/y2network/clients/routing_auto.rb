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
require "installation/auto_client"
require "y2network/config"
require "y2network/routing_helpers"

Yast.import "NetworkInterfaces"
Yast.import "Lan"

module Y2Network
  module Clients
    # This class is reponsible of the autoinstallation routing configuration.
    class RoutingAuto < ::Installation::AutoClient
      include RoutingHelpers
      include Yast::I18n
      include Yast::Logger

      class << self
        # @return [Boolean] whether the AutoYaST configuration has been
        # modified or not
        attr_accessor :changed
      end

      # Constructor
      def initialize
        textdomain "network"
      end

      # Import routing configuration
      #
      # @param profile [Hash] routing profile section to be imported
      # @return [Boolean]
      def import(profile = {})
        return unless config
        ip_forward = profile.fetch("ip_forward", false)
        ipv4_forward = profile.fetch("ipv4_forward", ip_forward)
        ipv6_forward = profile.fetch("ipv6_forward", ip_forward)

        interfaces = find_interfaces
        routes = profile.fetch("routes", []).map { |r| build_route(interfaces, r) }
        tables = [Y2Network::RoutingTable.new(routes)]
        config.routing =
          Y2Network::RoutingConfig.new(tables: [routing_table],
                                     forward_v4: ipv4_forward,
                                     forward_v6: ipv6_forward)
      end

      def export
        return {} unless config

        config.routing.to_h
      end

      def reset
        self.class.changed = false
      end

      def change
        log.info "Pending implementation"
      end

      def modified
        !!self.class.changed
      end

      def modified!
        self.class.changed = true
      end

    private

      def config
        Yast::Lan.configs.find { |c| c.id == "system" }
      end
    end
  end
end

