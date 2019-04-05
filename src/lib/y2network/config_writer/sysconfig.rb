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

        write_ip_forwarding(config.routing)
        # list of devices used in routes
        devices = config.routing.routes.map { |r| r.interface == :any ? :any : r.interface.name }.uniq
        devices.each do |dev|
          routes = config.routing.routes.select { |r| dev == :any || r.interface.name == dev }

          writer = if dev == :any
            ConfigWriter::SysconfigRoutesWriter.new
          else
            ConfigWriter::SysconfigRoutesWriter.new(
              routes_file: "/etc/sysconfig/network/ifroute-#{dev}"
            )
          end

          writer.write(routes)
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
    end
  end
end
