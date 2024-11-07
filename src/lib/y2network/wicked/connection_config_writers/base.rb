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

module Y2Network
  module Wicked
    module ConnectionConfigWriters
      # This is the base class for connection config writers.
      #
      # The derived classes should implement {#update_file} method.
      class Base
        extend Forwardable
        # @return [CFA::InterfaceFile] Interface's configuration file
        attr_reader :file

        # Constructor
        #
        # @param file [CFA::InterfaceFile] Interface's configuration file
        def initialize(file)
          @file = file
        end

        # Writes connection information to the interface configuration file
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Connection to take settings from
        def write(conn)
          file.bootproto = value_as_string(conn.bootproto.to_s)
          file.name = value_as_string(conn.description)
          file.lladdr = value_as_string(conn.lladdress)
          file.startmode = value_as_string(startmode_for(conn))
          file.dhclient_set_hostname = value_as_string(dhclient_set_hostname(conn))
          file.ifplugd_priority = conn.startmode.priority if conn.startmode.to_s == "ifplugd"
          file.ethtool_options = value_as_string(conn.ethtool_options)
          file.zone = value_as_string(conn.firewall_zone)
          file.mtu = conn.mtu unless conn.mtu.to_i.zero?
          add_ips(conn)

          update_file(conn)
          add_hostname(conn) if conn.static?
        end

      private

        # Sets file values from the given connection configuration
        #
        # @note This method should be redefined by derived classes.
        #
        # @param _conn [Y2Network::ConnectionConfig::Base]
        def update_file(_conn); end

        def dhclient_set_hostname(conn)
          case conn.dhclient_set_hostname
          when true then "yes"
          when false then "no"
          when nil then nil
          else
            raise "Unknown value #{conn.dhclient_set_hostname.inspect}"
          end
        end

        # Adds IP addresses
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Connection to take settings from
        def add_ips(conn)
          file.ipaddrs.clear
          ips_to_add = conn.ip_aliases.clone
          ips_to_add << conn.ip if conn.static_valid_ip?
          ips_to_add.each { |i| add_ip(i) }
        end

        # Adds a single IP to the file
        #
        # @param ip [Y2Network::IPAddress] IP address to add
        def add_ip(ip)
          file.ipaddrs[ip.id] = ip.address
          file.labels[ip.id] = value_as_string(ip.label)
          file.remote_ipaddrs[ip.id] = ip.remote_address
          file.broadcasts[ip.id] = ip.broadcast
        end

        # Adds the hostname to /etc/hosts
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Connection to take settings from
        def add_hostname(conn)
          return unless conn.hostnames && conn.ip
          return if conn.hostnames.empty?

          Yast::Host.Update("", conn.hostname, conn.ip.address.address.to_s)
        end

        # Converts the value into a string (or nil if empty)
        #
        # @param [String] value
        # @return [String,nil]
        def value_as_string(value)
          (value.nil? || value.empty?) ? nil : value
        end

        # Obtains the startmode to be used for the connection given
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Connection to take settings from
        # @return [String] startmode be written
        def startmode_for(conn)
          return "" unless conn.startmode

          conn.startmode.alias_name || conn.startmode.name
        end
      end
    end
  end
end
