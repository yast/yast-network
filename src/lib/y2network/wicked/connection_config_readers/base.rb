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

require "y2network/connection_config/ip_config"
require "y2network/ip_address"
require "y2network/boot_protocol"
require "y2network/startmode"

Yast.import "Host"

module Y2Network
  module Wicked
    module ConnectionConfigReaders
      # This is the base class for connection config readers.
      #
      # The derived classes should implement {#update_connection_config} method.
      # methods.
      class Base
        # @return [CFA::InterfaceFile] Interface's configuration file
        attr_reader :file

        # Constructor
        #
        # @param file [CFA::InterfaceFile] Interface's configuration file
        # @param issues_list [Y2Issues::List] List to register issues
        def initialize(file, issues_list)
          @file = file
          @issues_list = issues_list
        end

        # Builds a connection configuration object
        #
        # @return [Y2Network::ConnectionConfig::Base]
        def connection_config
          connection_class.new.tap do |conn|
            conn.bootproto = find_bootproto
            conn.description = file.name
            conn.interface = file.interface
            conn.ip = all_ips.find { |i| i.id.empty? }
            conn.ip_aliases = all_ips.reject { |i| i.id.empty? }
            conn.name = file.interface
            conn.lladdress = file.lladdr
            conn.startmode = find_startmode
            conn.startmode.priority = file.ifplugd_priority if conn.startmode.name == "ifplugd"
            conn.ethtool_options = file.ethtool_options
            conn.firewall_zone = file.zone
            if file.dhclient_set_hostname
              conn.dhclient_set_hostname = file.dhclient_set_hostname == "yes"
            end
            conn.hostnames = hostnames(conn)
            conn.mtu = file.mtu

            update_connection_config(conn)
          end
        end

      private

        # @return [Y2Issues::List] List to register issues
        attr_reader :issues_list

        DEFAULT_BOOTPROTO = BootProtocol::STATIC

        # Finds the boot protocol
        #
        # If it is not defined or it has an unknown value, it returns the
        # fallback value (BootProtocol::STATIC).
        #
        # @return [BootProtocol]
        def find_bootproto
          bootproto = BootProtocol.from_name(file.bootproto.to_s)
          return bootproto if bootproto

          issue_location = "file:#{file.path}:BOOTPROTO"
          issue = Y2Issues::InvalidValue.new(
            file.bootproto, fallback: BootProtocol::STATIC, location: issue_location
          )
          issues_list << issue

          BootProtocol::STATIC
        end

        DEFAULT_STARTMODE_NAME = "manual".freeze

        # Finds the start mode
        #
        # If it is not defined or it has an unknown value, it returns the
        # fallback value (manual).
        #
        # @return [Startmode]
        def find_startmode
          startmode = Startmode.create(file.startmode) if file.startmode
          return startmode if startmode

          issue_location = "file:#{file.path}:STARTMODE"
          fallback = Startmode.create(DEFAULT_STARTMODE_NAME)
          issue = Y2Issues::InvalidValue.new(
            file.startmode, fallback: fallback, location: issue_location
          )
          issues_list << issue
          fallback
        end

        # Returns the class of the connection configuration
        #
        # @return [Class]
        def connection_class
          class_name = self.class.to_s.split("::").last
          file_name = class_name.gsub(/(\w)([A-Z])/, "\\1_\\2").downcase
          require "y2network/connection_config/#{file_name}"
          Y2Network::ConnectionConfig.const_get(class_name)
        end

        # Sets connection config settings from the given file
        #
        # @note This method should be redefined by derived classes.
        #
        # @param _conn [Y2Network::ConnectionConfig::Base]
        def update_connection_config(_conn); end

        # Returns the IPs configuration from the file
        #
        # @return [Array<Y2Network::ConnectionConfig::IPAdress>] IP addresses configuration
        # @see Y2Network::ConnectionConfig::IPConfig
        def all_ips
          @all_ips ||= file.ipaddrs.each_with_object([]) do |(id, ip), all|
            next unless ip.is_a?(Y2Network::IPAddress)

            ip_address = build_ip(ip, id)

            all << Y2Network::ConnectionConfig::IPConfig.new(
              ip_address,
              id:             id,
              label:          file.labels[id],
              remote_address: file.remote_ipaddrs[id],
              broadcast:      file.broadcasts[id]
            )
          end
        end

        # Builds an IP address
        #
        # It takes an IP address and, optionally, a prefix or a netmask.
        #
        # @param ip      [Y2Network::IPAddress] IP address
        # @param id      [String] Hash key for the IP Address
        def build_ip(ip, id)
          ipaddr = ip.clone
          return ipaddr if ip.prefix?

          assign_ip_netmask(ipaddr, id)
          assign_ip_prefix(ipaddr, id)

          ipaddr
        end

        # @param ip      [Y2Network::IPAddress] IP address
        # @param id      [String] Hash key for the IP Address
        def assign_ip_netmask(ip, id)
          netmask = file.netmasks[id]
          return ip unless netmask

          begin
            ip.netmask = netmask
          rescue StandardError
            issue_location = "file:#{file.path}:NETMASK#{id}"
            issue = Y2Issues::InvalidValue.new(
              netmask, fallback: nil, location: issue_location
            )
            issues_list << issue
          end
        end

        # @param ip      [Y2Network::IPAddress] IP address
        # @param id      [String] Hash key for the IP Address
        def assign_ip_prefix(ip, id)
          prefix = file.prefixlens[id]
          return ip unless prefix

          address = ip.address.clone
          begin
            # Take advantage of the IPAddress address validations when the prefix is assigned not
            # allowing an invalid one (bsc#1206551)
            address.prefix = prefix
            ip.prefix = prefix
          rescue StandardError
            issue_location = "file:#{file.path}:PREFIXLEN#{id}"
            issue = Y2Issues::InvalidValue.new(
              prefix, fallback: nil, location: issue_location
            )
            issues_list << issue
          end
        end

        # Returns the hostnames for the given connection
        #
        # @return [Array<String>]
        def hostnames(conn)
          return [] unless conn.ip

          Yast::Host.Read
          aliases = Yast::Host.names(conn.ip.address.address.to_s).first
          aliases.to_s.split(" ")
        end
      end
    end
  end
end
