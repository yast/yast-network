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
require "cfa/sysctl_config"
require "y2network/config"
require "y2network/config_reader"
require "y2network/interface"
require "y2network/routing"
require "y2network/routing_table"
require "cfa/routes_file"
require "y2network/wicked/dns_reader"
require "y2network/wicked/hostname_reader"
require "y2network/wicked/interfaces_reader"
require "y2network/wicked/connection_configs_reader"
require "y2network/issues_result"
require "y2issues"

Yast.import "Host"

module Y2Network
  module Wicked
    # This class reads the current configuration from `/etc/sysconfig` files
    class ConfigReader < Y2Network::ConfigReader
      include Yast::Logger

      SECTIONS = [
        :interfaces, :connections, :drivers, :routing, :dns, :hostname
      ].freeze

      # @return [IssuesResult] Network configuration
      def read
        # NOTE: This code might be moved outside of the Sysconfig namespace, as it is generic.
        # NOTE: /etc/hosts cache - nothing to do with /etc/hostname
        Yast::Host.Read

        initial_config = Config.new(source: :wicked)
        issues_list = Y2Issues::List.new

        network_config = SECTIONS.reduce(initial_config) do |current_config, section|
          send("read_#{section}", current_config, issues_list)
        end

        log.info "Sysconfig reader result: #{network_config.inspect}"
        IssuesResult.new(network_config, issues_list)
      end

    protected

      # Reads the network interfaces
      #
      # @param config [Y2Network::Config] Initial configuration object
      # @param _issues_list [Y2Issues::List] Issues list. Used to register issues when reading.
      # @return [Y2Network::Config] A new configuration object including the interfaces
      def read_interfaces(config, _issues_list)
        config.update(
          interfaces:   interfaces_reader.interfaces,
          s390_devices: interfaces_reader.s390_devices
        )
      end

      # Reads the connections
      #
      # @param config [Y2Network::Config] Initial configuration object
      # @param issues_list [Y2Issues::List] Issues list. Used to register issues when reading.
      # @return [Y2Network::Config] A new configuration object including the connections
      def read_connections(config, issues_list)
        connection_configs_reader = ConnectionConfigsReader.new(issues_list)
        connections = connection_configs_reader.connections(config.interfaces)
        missing_interfaces = find_missing_interfaces(
          connections, config.interfaces
        )
        config.update(
          interfaces:  config.interfaces + missing_interfaces,
          connections: connections
        )
      end

      # Reads the drivers
      #
      # @param config [Y2Network::Config] Initial configuration object
      # @param _issues_list [Y2Issues::List] Issues list. Used to register issues when reading.
      # @return [Y2Network::Config] A new configuration object including the connections
      def read_drivers(config, _issues_list)
        config.update(drivers: interfaces_reader.drivers)
      end

      # Reads the routing information
      #
      # @param config [Y2Network::Config] Initial configuration object
      # @param _issues_list [Y2Issues::List] Issues list. Used to register issues when reading.
      # @return [Y2Network::Config] A new configuration object including the routing information
      def read_routing(config, _issues_list)
        routing_tables = find_routing_tables(config.interfaces)
        routing = Routing.new(
          tables:       routing_tables,
          forward_ipv4: sysctl_config_file.forward_ipv4,
          forward_ipv6: sysctl_config_file.forward_ipv6
        )
        config.update(routing: routing)
      end

      # Reads the DNS information
      #
      # @param config [Y2Network::Config] Initial configuration object
      # @param _issues_list [Y2Issues::List] Issues list. Used to register issues when reading.
      # @return [Y2Network::Config] A new configuration object including the DNS configuration
      def read_dns(config, _issues_list)
        config.update(dns: Y2Network::Wicked::DNSReader.new.config)
      end

      # Returns the Hostname configuration
      #
      # @param config [Y2Network::Config] Initial configuration object
      # @param _issues_list [Y2Issues::List] Issues list. Used to register issues when reading.
      # @return [Y2Network::Config] A new configuration object including the hostname information
      def read_hostname(config, _issues_list)
        config.update(hostname: Y2Network::Wicked::HostnameReader.new.config)
      end

    private

      # Returns an interfaces reader instance
      #
      # @return [InterfacesReader] Interfaces reader
      def interfaces_reader
        @interfaces_reader ||= Y2Network::Wicked::InterfacesReader.new
      end

      # Adds missing interfaces from connections
      #
      # @param connections [Y2Network::InterfacesCollection] Known interfaces
      # @param interfaces [Y2Network::ConnectionConfigsCollection] Known interfaces
      def find_missing_interfaces(connections, interfaces)
        empty_collection = Y2Network::InterfacesCollection.new
        connections.to_a.each_with_object(empty_collection) do |conn, all|
          interface = interfaces.by_name(conn.interface)
          next if interface

          missing_interface =
            if conn.virtual?
              VirtualInterface.from_connection(conn)
            else
              PhysicalInterface.new(conn.name, hardware: Hwinfo.for(conn.name))
            end
          all << missing_interface
        end
      end

      # Reads routes
      #
      # Merges routes from /etc/sysconfig/network/routes and /etc/sysconfig/network/ifroute-*
      # TODO: currently it implicitly loads main/default routing table
      #
      # @param interfaces [Array<Interface>] Existing interfaces
      # @return [RoutingTable] an object with routes
      def find_routing_tables(interfaces)
        main_routes = load_routes_from
        iface_routes = interfaces.flat_map do |iface|
          if iface.name.empty?
            [] # not activated s390 devices, does not have name and so no routes file
          else
            load_routes_from("/etc/sysconfig/network/ifroute-#{iface.name}")
          end
        end
        all_routes = main_routes + iface_routes
        link_routes_to_interfaces(all_routes, interfaces)
        log.info "found routes #{all_routes.inspect}"
        [Y2Network::RoutingTable.new(all_routes.uniq)]
      end

      # Load a set of routes for a given path
      def load_routes_from(path = nil)
        klass = CFA::RoutesFile
        file = path ? klass.new(path) : klass.new
        file.load
        file.routes
      end

      # Links routes to interfaces objects
      #
      # {CFA::RoutesFile} knows nothing about the already detected interfaces, so
      # it instantiates a new object for each interface found. This method links the routes
      # with the interfaces found in #interfaces.
      #
      # @param routes     [Array<Route>] Routes to link
      # @param interfaces [Array<Interface>] Interfaces
      def link_routes_to_interfaces(routes, interfaces)
        routes.each do |route|
          next unless route.interface

          interface = interfaces.by_name(route.interface.name)
          route.interface = interface if interface
        end
      end

      # Returns the Sysctl_Config file class
      #
      # @return [CFA::SysctlConfig]
      def sysctl_config_file
        return @sysctl_config_file if @sysctl_config_file

        @sysctl_config_file = CFA::SysctlConfig.new
        @sysctl_config_file.load
        @sysctl_config_file
      end
    end
  end
end
