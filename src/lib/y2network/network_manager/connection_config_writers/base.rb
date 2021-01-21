# Copyright (c) [2021] SUSE LLC
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

require "y2network/boot_protocol"
require "securerandom"

module Y2Network
  module NetworkManager
    module ConnectionConfigWriters
      # Base class for connection config writers.
      #
      # The derived classes should implement a {#update_file} method.
      class Base
        # @return [CFA::NmConnection] Connection configuration file
        attr_reader :file

        # Constructor
        #
        # @param file [CFA::NmConnection] Connection configuration file
        def initialize(file)
          @file = file
        end

        # Writes connection information to the interface configuration file
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Connection to take settings from
        # @param routes [<Array<Y2Network::Route>] routes associated with the connection
        def write(conn, routes = [])
          file.connection["id"] = conn.name
          file.connection["autoconnect"] = "false" if ["manual", "off"].include? conn.startmode.name
          file.connection["permissions"] = nil
          file.connection["interface-name"] = conn.interface
          file.connection["zone"] = conn.firewall_zone unless ["", nil].include? conn.firewall_zone
          conn.bootproto.dhcp? ? configure_dhcp(conn) : configure_ips(conn)
          configure_routes(routes)
          update_file(conn)
        end

      private

        # Convenience method to write routing configuration associated with the
        # connection config to be written
        #
        # @param routes [<Array<Y2Network::Route>] routes associated with the connection
        def configure_routes(routes)
          routes.select(&:default?).each { |r| configure_gateway(r) }
        end

        # @param route [Y2Network::Route] route to be written
        def configure_gateway(route)
          section = route.gateway.ipv4? ? file.ipv4 : file.ipv6
          section["gateway"] = route.gateway.to_s
        end

        # FIXME: Gateway is missing
        # Convenience method for writing the static IP configuration
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Connection to take settings from
        def configure_ips(conn)
          ips_to_add = conn.ip_aliases.clone
          ips_to_add.append(conn.ip) if conn.ip
          ipv4 = ips_to_add.select { |i| i&.address&.ipv4? }.map { |i| i.address.to_s }
          ipv6 = ips_to_add.select { |i| i&.address&.ipv6? }.map { |i| i.address.to_s }

          unless ipv4.empty?
            file.ipv4["method"] = "manual"
            file.add_collection("ipv4", "address", ipv4)
          end

          return if ipv6.empty?

          file.ipv6["method"] = "manual"
          file.add_collection("ipv6", "address", ipv6)
        end

        # Convenience method for writing the DHCP config
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Connection to take settings from
        def configure_dhcp(conn)
          file.ipv4["method"] = "auto" if conn.bootproto != Y2Network::BootProtocol::DHCP6
          file.ipv6["method"] = "auto" if conn.bootproto != Y2Network::BootProtocol::DHCP4
        end

        # Sets file values from the given connection configuration
        #
        # @note This method should be redefined by derived classes.
        #
        # @param _conn [Y2Network::ConnectionConfig::Base]
        def update_file(_conn); end
      end
    end
  end
end
