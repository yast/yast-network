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
require "y2network/sysconfig_routes_file"

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

        write_ip_forwarding(config.routing)

        # list of devices used by routes
        devices = config.interfaces + [nil]

        devices.each do |dev|
          routes = find_routes_for(dev, config.routing.routes)
          file = routes_file_for(dev)

          # Remove ifroutes-* if empty, but not /etc/sysconfig/network/route
          if dev && routes.empty?
            file.remove
          else
            file.routes = routes
            file.save
          end
        end
      end

    private

      include SysconfigPaths

      # Writes ip forwarding setup
      #
      # @param routing [Y2Network::Routing] routing configuration
      def write_ip_forwarding(routing)
        write_ipv4_forwarding(routing.forward_ipv4)
        write_ipv6_forwarding(routing.forward_ipv6)

        nil
      end

      # Configures system for IPv4 forwarding
      #
      # @param forward_ipv4 [Boolean] true when forwarding should be enabled
      # @return [Boolean] true on success
      def write_ipv4_forwarding(forward_ipv4)
        sysctl_val = forward_ipv4 ? "1" : "0"

        Yast::SCR.Write(
          Yast::Path.new(SYSCTL_IPV4_PATH),
          sysctl_val
        )
        Yast::SCR.Write(Yast::Path.new(SYSCTL_AGENT_PATH), nil)

        Yast::SCR.Execute(Yast::Path.new(".target.bash"), "/usr/sbin/sysctl -w #{IPV4_SYSCTL}=#{sysctl_val.shellescape}") == 0
      end

      # Configures system for IPv6 forwarding
      #
      # @param forward_ipv6 [Boolean] true when forwarding should be enabled
      # @return [Boolean] true on success
      def write_ipv6_forwarding(forward_ipv6)
        sysctl_val = forward_ipv6 ? "1" : "0"

        Yast::SCR.Write(
          Yast::Path.new(SYSCTL_IPV6_PATH),
          sysctl_val
        )
        Yast::SCR.Write(Yast::Path.new(SYSCTL_AGENT_PATH), nil)

        Yast::SCR.Execute(Yast::Path.new(".target.bash"), "/usr/sbin/sysctl -w #{IPV6_SYSCTL}=#{sysctl_val.shellescape}") == 0
      end

      # Finds routes for a given interface or the routes not tied to any
      # interface in case of nil
      #
      # @param iface  [Interface,nil] Interface to search routes for; nil will
      #   return the routes not tied to any interface
      # @param routes [Array<Route>] List of routes to search in
      # @return [Array<Route>] List of routes for the given interface
      #
      # @see #find_routes_for_iface
      def find_routes_for(iface, routes)
        iface ? find_routes_for_iface(iface, routes) : routes.select { |r| !r.interface }
      end

      # Finds routes for a given interface
      #
      # @param iface  [Interface] Interface to search routes for
      # @param routes [Array<Route>] List of routes to search in
      # @return [Array<Route>] List of routes for the given interface
      def find_routes_for_iface(iface, routes)
        routes.select do |route|
          route.interface && route.interface.name == iface.name
        end
      end

      # Returns the routes file for a given interace
      #
      # @param iface  [Interface,nil] Interface to search routes for; nil will
      #   return the global routes file
      # @return [Y2Network::SysconfigRoutesFile]
      def routes_file_for(iface)
        return Y2Network::SysconfigRoutesFile.new unless iface
        Y2Network::SysconfigRoutesFile.new("/etc/sysconfig/network/ifroute-#{iface.name}")
      end
    end
  end
end
