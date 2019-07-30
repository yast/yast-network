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
  module Sysconfig
    module ConnectionConfigWriters
      # This is the base class for connection config writers.
      #
      # The derived classes should implement {#update_file} method.
      class Base
        # @return [Y2Network::Sysconfig::InterfaceFile] Interface's configuration file
        attr_reader :file

        # Constructor
        #
        # @param file [Y2Network::Sysconfig::InterfaceFile] Interface's configuration file
        def initialize(file)
          @file = file
        end

        # Writes connection information to the interface configuration file
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Connection to take settings from
        def write(conn)
          file.bootproto = conn.bootproto.name
          file.name = conn.description
          file.startmode = conn.startmode.to_s
          file.ifplugd_priority = conn.startmode.priority if conn.startmode.name == "ifplugd"
          write_all_ips(conn.all_ips)
          update_file(conn)
        end

      private

        # Sets file values from the given connection configuration
        #
        # @note This method should be redefined by derived classes.
        #
        # @param _conn [Y2Network::ConnectionConfig::Base]
        def update_file(_conn)
          raise NotImplementedError
        end

        # Write IP configuration
        #
        # @param all_ips [Array<Y2Network::ConnectionConfig::IPConfig>] IPs configuration
        def write_all_ips(all_ips)
          all_ips.each do |ip_config|
            file.ipaddrs[ip_config.id] = ip_config.address
            file.labels[ip_config.id] = ip_config.label
            file.remote_ipaddrs[ip_config.id] = ip_config.remote_address
            file.broadcasts.merge!(ip_config.id => ip_config.broadcast)
          end
        end
      end
    end
  end
end
