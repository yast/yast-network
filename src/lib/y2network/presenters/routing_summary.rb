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
Yast.import "Summary"
Yast.import "NetHwDetection"

module Y2Network
  module Presenters
    # This class converts a routing configuration object into a hash to be used
    # in an AutoYaST summary
    class RoutingSummary
      include Yast::I18n

      # @return [Y2Network::Routing]
      attr_reader :routing

      # Constructor
      #
      # @param config [Y2Network::Routing] Network configuration to represent
      def initialize(routing)
        textdomain "network"
        @routing = routing
      end

      # Returns the summary of network configuration settings in text form
      #
      # @todo Implement the real summary.
      #
      # @return [String]
      def text
        summary = ""
        return summary if routing.nil? || routing.routes.empty?

        gateway_string = gateway_string_from(routing)
        if gateway_string
          summary = Yast::Summary.AddListItem(summary, _("Gateway: %s") % gateway_string)
        end
        summary = Yast::Summary.AddListItem(
          summary, format(_("IP Forwarding for IPv4: %s"), boolean_to_human(routing.forward_ipv4))
        )
        summary = Yast::Summary.AddListItem(
          summary, format(_("IP Forwarding for IPv6: %s"), boolean_to_human(routing.forward_ipv6))
        )

        "<ul>#{summary}</ul>"
      end

    private

      # Returns a text representation of the gateway
      #
      # @param routing [Y2Network::Routing] Routing configuration
      # @return [String,nil] Text representation of the gateway IP; nil if no gateway is found
      def gateway_string_from(routing)
        default_route = routing.default_route
        return nil if default_route.nil?
        gateway = default_route.gateway.to_s
        hostname = Yast::NetHwDetection.ResolveIP(gateway)
        return gateway if hostname.empty?
        "#{gateway} (#{hostname})"
      end

      # Converts a boolean into a on/off string
      #
      # @param value [Boolean] Value to convert
      # @return [String] "on" if +value+ is true; false otherwise
      def boolean_to_human(value)
        value ? _("on") : _("off")
      end
    end
  end
end
