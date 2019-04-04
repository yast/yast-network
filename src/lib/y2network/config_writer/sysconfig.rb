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
require "y2network/sysconfig_paths"
require "y2network/config_reader/sysconfig_routes_reader"

module Y2Network
  module ConfigWriter
    # This class imports a configuration into YaST modules
    #
    # Ideally, it should be responsible of writing the changes to the underlying
    # system. But, for the time being, it just relies in {Yast::Routing}.
    class Sysconfig
      # Writes the configuration into YaST network related modules
      #
      # @param config [Y2Network::Config] Configuration to write
      def write(config)
        return unless config.routing

        routes = config.routing.routes.map { |r| route_to_hash(r) }
        Yast::Routing.Import(
          "ipv4_forward" => config.routing.forward_ipv4,
          "ipv6_forward" => config.routing.forward_ipv6,
          "routes"       => routes
        )
      end

    private

      include SysconfigPaths

      # Writes ip forwarding setup
      #
      # @param routing [Y2Network::Routing] routing configuration
      # @return [Boolean] true on success
      def write_ip_forwarding(routing)
        write_ipv4_forwarding(routing.forward_ipv4) && write_ipv6_forwarding(routing.forward_ipv6)
      end

      # Configures system for IPv4 forwarding
      #
      # @param forward_ipv4 [Boolean] true when forwarding should be enabled
      # @return [Boolean] true on success
      def write_ipv4_forwarding(forward_ipv4)
        sysctl_val = forward_ipv4 ? "1" : "0"

        SCR.Write(
          path(SYSCTL_IPV4_PATH),
          sysctl_val
        )
        SCR.Write(path(SYSCTL_AGENT_PATH), nil)

        SCR.Execute(path(".target.bash"), "/usr/sbin/sysctl -w #{IPV4_SYSCTL}=#{sysctl_val.shellescape}") == 0
      end

      # Configures system for IPv6 forwarding
      #
      # @param forward_ipv6 [Boolean] true when forwarding should be enabled
      # @return [Boolean] true on success
      def write_ipv6_forwarding(forward_ipv6)
        sysctl_val = forward_ipv6 ? "1" : "0"

        SCR.Write(
          path(SYSCTL_IPV6_PATH),
          sysctl_val
        )
        SCR.Write(path(SYSCTL_AGENT_PATH), nil)

        SCR.Execute(path(".target.bash"), "/usr/sbin/sysctl -w #{IPV6_SYSCTL}=#{sysctl_val.shellescape}") == 0
      end

      # Returns a hash containing the route information to be imported into {Yast::Routing}
      #
      # @param route [Y2Network::Route]
      # @return [Hash]
      def route_to_hash(route)
        hash =
          if route.default?
            { "destination" => "default", "netmask" => "-" }
          else
            { "destination" => route.to.to_s, "netmask" => netmask(route.to) }
          end
        hash.merge("options" => route.options) unless route.options.to_s.empty?
        hash.merge(
          "gateway" => route.gateway ? route.gateway.to_s : "-",
          "device"  => route.interface == :any ? "-" : route.interface.name
        )
      end

      IPV4_MASK = "255.255.255.255".freeze
      IPV6_MASK = "fffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff".freeze

      # Returns the netmask
      #
      # @param ip [IPAddr]
      # @return [IPAddr]
      def netmask(ip)
        mask = ip.ipv4? ? IPV4_MASK : IPV6_MASK
        IPAddr.new(mask).mask(ip.prefix).to_s
      end
    end
  end
end
