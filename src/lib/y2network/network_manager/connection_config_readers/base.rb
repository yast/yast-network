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

module Y2Network
  module NetworkManager
    module ConnectionConfigReaders
      # This is the base class for connection config readers.
      #
      # The derived classes should reimplement the {#update_connection_config}
      # method.
      class Base
        # @return [CFA::NmConnection] Connection configuration file
        attr_reader :file

        # Constructor
        #
        # @return [CFA::NmConnection] Connection configuration file
        def initialize(file)
          @file = file
        end

        # Builds a connection configruation object from the file
        #
        # @return [Y2Network::ConnectionConfig::Base]
        def connection_config
          connection_class.new.tap do |conn|
            conn.bootproto = bootproto
            conn.name = file.connection["id"]
            conn.description = conn.name.clone
            conn.startmode = startmode
            conn.firewall_zone = file.connection["zone"]
            conn.ip = all_ips.first
            conn.ip_aliases = all_ips[1..-1]
            # TODO: hostnames (pending)
            update_connection_config(conn)
          end
        end

      protected

        # Sets connection config settings from the given file.
        #
        # @note This method is expected to be redefined by derived classes.
        #
        # @param _conn [Y2Network::ConnectionConfig::Base]
        def update_connection_config(_conn); end

      private

        # Returns the class of the connection configuration
        #
        # TODO: duplicated (see Y2Network::Wicked::ConnectionConfigReaders::Base)
        #
        # @return [Class]
        def connection_class
          class_name = self.class.to_s.split("::").last
          file_name = class_name.gsub(/(\w)([A-Z])/, "\\1_\\2").downcase
          require "y2network/connection_config/#{file_name}"
          Y2Network::ConnectionConfig.const_get(class_name)
        end

        NM_DHCP = "auto".freeze

        # Determines the value for the BOOTPROTO parameter
        #
        # @return [Y2Network::BootProtocol]
        def bootproto
          ipv4_method = file.ipv4["method"]
          ipv6_method = file.ipv6["method"]

          if ipv4_method == NM_DHCP && ipv6_method == NM_DHCP
            Y2Network::BootProtocol::DHCP
          elsif ipv4_method == NM_DHCP
            Y2Network::BootProtocol::DHCP4
          elsif ipv6_method == NM_DHCP
            Y2Network::BootProtocol::DHCP6
          elsif ipv4_method || ipv6_method
            Y2Network::BootProtocol::STATIC
          else
            Y2Network::BootProtocol::NONE
          end
        end

        # Determines the value for the STARTMODE parameter
        #
        # @return [Y2]
        def startmode
          return Y2Network::Startmode.create("off") if file.connection["autoconnect"] == "false"

          Y2Network::Startmode.create("auto")
        end

        def all_ips
          @all_ips = ips_from_section(file.ipv4) + ips_from_section(file.ipv6)
        end

        def ips_from_section(section)
          address_items = section.data.select { |i| i[:key] =~ /\Aaddress\d+\Z/ }
          address_items.map do |item|
            addr, _gateway = item[:value].split(",")
            ip_address = Y2Network::IPAddress.from_string(addr)
            # TODO: handle the gateway too
            Y2Network::ConnectionConfig::IPConfig.new(ip_address)
          end
        end
      end
    end
  end
end
