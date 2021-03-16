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
      def write_connections(config, _old_config)
        writer = Y2Network::NetworkManager::ConnectionConfigWriter.new
        config.connections.each do |conn|
          opts = {
            routes: routes_for(conn, config.routing.routes),
            parent: conn.find_master(config.connections)
          }.reject { |_k, v| v.nil? }
          writer.write(conn, nil, **opts) # FIXME
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
    end
  end
end
