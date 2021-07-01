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

require "y2network/config_writer"
require "y2network/network_manager/connection_config_writer"

module Y2Network
  module NetworkManager
    # This class configures NetworkManager according to a given configuration
    class ConfigWriter < Y2Network::ConfigWriter
    private # rubocop:disable Layout/IndentationWidth

      # Writes connections configuration
      #
      # @todo Handle old connections (removing those that are not needed, etc.)
      #
      # @param config     [Y2Network::Config] Current config object
      # @param _old_config [Y2Network::Config,nil] Config object with original configuration
      def write_connections(config, _old_config, _issues_list)
        writer = Y2Network::NetworkManager::ConnectionConfigWriter.new
        config.connections.each do |conn|
          opts = {
            routes: routes_for(conn, config.routing.routes),
            parent: conn.find_master(config.connections)
          }
          writer.write(conn, nil, opts)
        end
      end

      # Updates the DNS configuration
      #
      # In case a connection has a static configuration, the DNS nameservers are added
      # to the configuration file (see bsc#1181701).
      #
      # @param config     [Y2Network::Config] Current config object
      # @param old_config [Y2Network::Config,nil] Config object with original configuration
      def write_dns(config, old_config, _issues_list)
        static = config.connections.by_bootproto(Y2Network::BootProtocol::STATIC)
        return super if static.empty? || config.dns.nameservers.empty?

        ipv4_ns, ipv6_ns = config.dns.nameservers.partition(&:ipv4?)
        ipv4_dns = ipv4_ns.map(&:to_s).join(";")
        ipv6_dns = ipv6_ns.map(&:to_s).join(";")
        static.each do |conn|
          add_dns_to_conn(conn, ipv4_dns, ipv6_dns)
        end
      end

      # Finds routes for a given connection
      #
      # @param conn [ConnectionConfig::Base] Connection configuration
      # @param routes [Array<Route>] List of routes to search in
      # @return [Array<Route>] List of routes for the given connection
      def routes_for(conn, routes)
        routes.select { |r| r.interface&.name == conn.name }
      end

      # Add the DNS settings to the nmconnection file corresponding to the give conn
      #
      # @param conn [Connectionconfig::Base] Connection configuration
      # @param ipv4_dns [String] Value for the 'dns' key in the ipv4 section
      # @param ipv6_dns [String] Value for the 'dns' key in the ipv6 section
      def add_dns_to_conn(conn, ipv4_dns, ipv6_dns)
        file = CFA::NmConnection.for(conn)
        return unless file.exist?

        file.load
        file.ipv4["dns"] = ipv4_dns unless ipv4_dns.empty?
        file.ipv6["dns"] = ipv6_dns unless ipv6_dns.empty?
        file.save
      end
    end
  end
end
