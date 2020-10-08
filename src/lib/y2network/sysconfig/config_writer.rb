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
require "y2network/sysconfig/routes_file"
require "y2network/sysconfig/dns_writer"
require "y2network/sysconfig/hostname_writer"
require "y2network/sysconfig/connection_config_writer"
require "y2network/sysconfig/interfaces_writer"
require "cfa/sysctl_config"

Yast.import "Host"

module Y2Network
  module Sysconfig
    # This class imports a configuration into YaST modules
    #
    # Ideally, it should be responsible of writing the changes to the underlying
    # system.
    class ConfigWriter
      include Yast::Logger

      # @return [Array<Symbol>] The different sections handled by the writer
      SECTIONS = [:routing, :drivers, :interfaces, :connections, :dns, :hostname].freeze

      # Writes the configuration into YaST network related modules
      #
      # @param config     [Y2Network::Config] Configuration to write
      # @param old_config [Y2Network::Config] Old configuration
      # @param sections [Array<symbol>, :all] explicit sections to be written, by default if no
      #   parameter is given then all changes will be written
      def write(config, old_config = nil, sections: :all)
        # TODO: Improve the loging using better format
        log.info "Writing configuration: #{config.inspect}\n"
        log.info "Old configuration: #{old_config.inspect}\n"

        if sections == :all
          sections = SECTIONS
        else
          log.info("Writing sections: #{sections.inspect}")
        end

        SECTIONS.each { |s| send(:"write_#{s}", config, old_config) if sections.include?(s) }

        # NOTE: This code might be moved outside of the Sysconfig namespace, as it is generic.
        Yast::Host.Write(gui: false)
      end

    private

      # Updates the ip forwarding config and the routing config which does not
      # belongs to a particular interface
      #
      # @param config     [Y2Network::Config] Current config object
      # @param old_config [Y2Network::Config,nil] Config object with original configuration
      def write_routing(config, old_config)
        write_ip_forwarding(config.routing)

        # update /etc/sysconfig/network/routes file
        file = routes_file_for(nil)
        file.routes = find_routes_for(nil, config.routing.routes)
        file.save

        write_interface_routes(config, old_config)
      end

      # Writes the routes for the configured interfaces removing the ones not
      # configured
      #
      # @param config     [Y2Network::Config] current configuration for writing
      # @param old_config [Y2Network::Config, nil] original configuration used
      #                   for detecting changes. When nil, no actions related to
      #                   configuration changes are processed.
      def write_interface_routes(config, old_config)
        # Write ifroute files
        config.interfaces.each do |dev|
          # S390 devices that have not been activated yet will be part of the
          # collection but with an empty name.
          next if dev.name.empty?

          routes = find_routes_for(dev, config.routing.routes)
          file = routes_file_for(dev)

          # Remove ifroutes-* if empty or interface is not configured
          file.remove if routes.empty? || !config.configured_interface?(dev.name)

          file.routes = routes
          file.save
        end

        # Actions needed for removed interfaces
        removed_ifaces = old_config ? old_config.interfaces.to_a - config.interfaces.to_a : []
        removed_ifaces.each do |iface|
          file = routes_file_for(iface)
          file.remove
        end
        nil
      end

      # Writes ip forwarding setup
      #
      # @param routing [Y2Network::Routing] routing configuration
      def write_ip_forwarding(routing)
        sysctl_config = CFA::SysctlConfig.new
        sysctl_config.load
        sysctl_config.forward_ipv4 = routing.forward_ipv4
        sysctl_config.forward_ipv6 = routing.forward_ipv6
        sysctl_config.save unless sysctl_config.conflict?

        update_ip_forwarding((sysctl_config.forward_ipv4 ? "1" : "0"),
          :ipv4)
        update_ip_forwarding((sysctl_config.forward_ipv6 ? "1" : "0"),
          :ipv6)
        nil
      end

      IP_SYSCTL = {
        ipv4: "net.ipv4.ip_forward",
        ipv6: "net.ipv6.conf.all.forwarding"
      }.freeze

      # Updates the IP forwarding configuration of the running kernel
      #
      # @param value [String] "1" (enable) or "0" (disable).
      # @param type  [Symbol] :ipv4 or :ipv6
      def update_ip_forwarding(value, type)
        key = IP_SYSCTL[type]
        Yast::SCR.Execute(Yast::Path.new(".target.bash"),
          "/usr/sbin/sysctl -w #{key}=#{value.shellescape}")
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
      # @return [Y2Network::Sysconfig::RoutesFile]
      def routes_file_for(iface)
        return Y2Network::Sysconfig::RoutesFile.new unless iface

        Y2Network::Sysconfig::RoutesFile.new("/etc/sysconfig/network/ifroute-#{iface.name}")
      end

      # Updates the DNS configuration
      #
      # @param config     [Y2Network::Config] Current config object
      # @param old_config [Y2Network::Config,nil] Config object with original configuration
      def write_dns(config, old_config)
        old_dns = old_config.dns if old_config
        writer = Y2Network::Sysconfig::DNSWriter.new
        writer.write(config.dns, old_dns)
      end

      # Updates the Hostname configuration
      #
      # @param config     [Y2Network::Config] Current config object
      # @param old_config [Y2Network::Config,nil] Config object with original configuration
      def write_hostname(config, old_config)
        old_hostname = old_config.hostname if old_config
        writer = Y2Network::Sysconfig::HostnameWriter.new
        writer.write(config.hostname, old_hostname)
      end

      # Updates the interfaces configuration and the routes associated with
      # them
      #
      # @param config     [Y2Network::Config] Current config object
      # @param _old_config [Y2Network::Config,nil] Config object with original configuration
      def write_interfaces(config, _old_config)
        writer = Y2Network::Sysconfig::InterfacesWriter.new(reload: !Yast::Lan.write_only)
        writer.write(config.interfaces)
      end

      # Writes connections configuration
      #
      # @todo Handle old connections (removing those that are not needed, etc.)
      #
      # @param config     [Y2Network::Config] Current config object
      # @param old_config [Y2Network::Config,nil] Config object with original configuration
      def write_connections(config, old_config)
        # FIXME: this code might live in its own class
        writer = Y2Network::Sysconfig::ConnectionConfigWriter.new
        remove_old_connections(config.connections, old_config.connections, writer) if old_config
        config.connections.each do |conn|
          old_conn = old_config ? old_config.connections.by_ids(conn.id).first : nil
          writer.write(conn, old_conn)
        end
      end

      # Writes drivers options
      #
      # @param config     [Y2Network::Config] Current config object
      # @param _old_config [Y2Network::Config,nil] Config object with original configuration
      def write_drivers(config, _old_config)
        Y2Network::Driver.write_options(config.drivers)
      end

      # Removes old connections files
      #
      # @param conns [ConnectionConfigsCollection] New connections
      # @param old_conns [ConnectionConfigsCollection] Old connections
      # @param writer [Sysconfig::ConnectionConfigWriter] Writer instance to save changes
      def remove_old_connections(conns, old_conns, writer)
        ids_to_remove = old_conns.map(&:id) - conns.map(&:id)
        to_remove = old_conns.by_ids(*ids_to_remove)
        log.info "removing connections #{to_remove.map(&:name).inspect}"
        to_remove.each { |c| writer.remove(c) }
      end
    end
  end
end
