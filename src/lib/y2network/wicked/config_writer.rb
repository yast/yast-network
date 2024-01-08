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
require "y2network/config"
require "cfa/routes_file"
require "y2network/config_writer"
require "y2network/wicked/connection_config_writer"
require "cfa/sysctl_config"

module Y2Network
  module Wicked
    # This class configures Wicked (through sysconfig) according to a given configuration
    class ConfigWriter < Y2Network::ConfigWriter
    private

      # Updates the ip forwarding config and the routing config which does not
      # belongs to a particular interface
      #
      # @param config     [Y2Network::Config] Current config object
      # @param old_config [Y2Network::Config,nil] Config object with original configuration
      def write_routing(config, old_config, issues_list)
        write_ip_forwarding(config.routing, issues_list)

        # update /etc/sysconfig/network/routes file
        file = routes_file_for(nil)
        file.routes = find_routes_for(nil, config.routing.routes)
        file.save

        write_interface_routes(config, old_config, issues_list)
      end

      # Writes the routes for the configured interfaces removing the ones not
      # configured
      #
      # @param config     [Y2Network::Config] current configuration for writing
      # @param old_config [Y2Network::Config, nil] original configuration used
      #                   for detecting changes. When nil, no actions related to
      #                   configuration changes are processed.
      def write_interface_routes(config, old_config, _issues_list)
        # Write ifroute files
        config.interfaces.each do |dev|
          # S390 devices that have not been activated yet will be part of the
          # collection but with an empty name.
          next if dev.name.empty?

          routes = find_routes_for(dev, config.routing.routes)
          file = routes_file_for(dev)

          # Remove ifroutes-* if empty or interface is not configured
          if routes.empty? || !config.configured_interface?(dev.name)
            file.remove
          else
            file.routes = routes
            file.save
          end
        end

        # Actions needed for removed interfaces
        removed_ifaces = old_config ? old_config.interfaces - config.interfaces : []
        removed_ifaces.each do |iface|
          file = routes_file_for(iface)
          file.remove
        end
        nil
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
        iface ? find_routes_for_iface(iface, routes) : routes.reject(&:interface)
      end

      # Finds routes for a given interface
      #
      # @param iface  [Interface] Interface to search routes for
      # @param routes [Array<Route>] List of routes to search in
      # @return [Array<Route>] List of routes for the given interface
      def find_routes_for_iface(iface, routes)
        routes.select do |route|
          route.interface == iface
        end
      end

      # Returns the routes file for a given interace
      #
      # @param iface  [Interface,nil] Interface to search routes for; nil will
      #   return the global routes file
      # @return [CFA::RoutesFile]
      def routes_file_for(iface)
        return CFA::RoutesFile.new unless iface

        CFA::RoutesFile.new("/etc/sysconfig/network/ifroute-#{iface.name}")
      end

      # Writes connections configuration
      #
      # @todo Handle old connections (removing those that are not needed, etc.)
      #
      # @param config     [Y2Network::Config] Current config object
      # @param old_config [Y2Network::Config,nil] Config object with original configuration
      def write_connections(config, old_config, _issues_list)
        # FIXME: this code might live in its own class
        writer = Y2Network::Wicked::ConnectionConfigWriter.new
        remove_old_connections(config.connections, old_config.connections, writer) if old_config
        config.connections.each do |conn|
          old_conn = old_config ? old_config.connections.by_ids(conn.id).first : nil
          writer.write(conn, old_conn)
        end
      end

      # Removes old connections files
      #
      # @param conns [ConnectionConfigsCollection] New connections
      # @param old_conns [ConnectionConfigsCollection] Old connections
      # @param writer [Wicked::ConnectionConfigWriter] Writer instance to save changes
      def remove_old_connections(conns, old_conns, writer)
        ids_to_remove = old_conns.map(&:id) - conns.map(&:id)
        to_remove = old_conns.by_ids(*ids_to_remove)
        log.info "removing connections #{to_remove.map(&:name).inspect}"
        to_remove.each { |c| writer.remove(c) }
      end
    end
  end
end
