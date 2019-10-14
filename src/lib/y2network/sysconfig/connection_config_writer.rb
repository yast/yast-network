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

require "y2network/sysconfig/interface_file"
require "y2network/sysconfig/routes_file"

Yast.import "Host"

module Y2Network
  module Sysconfig
    # This class is responsible for writing interfaces changes
    class ConnectionConfigWriter
      include Yast::Logger

      # Writes connection config to the underlying system
      #
      # The method can receive the old configuration in order to perform clean-up tasks.
      #
      # @param conn [Y2Network::ConnectionConfig::Base] Connection configuration to write
      # @param old_conn [Y2Network::ConnectionConfig::Base,nil] Connection configuration to write
      def write(conn, old_conn = nil)
        return if conn == old_conn

        file = Y2Network::Sysconfig::InterfaceFile.new(conn.interface)
        handler_class = find_handler_class(conn.type)
        return nil if handler_class.nil?

        remove(old_conn) if old_conn
        file.clean
        handler_class.new(file).write(conn)
        file.save
      end

      # Removes connection config from the underlying system
      #
      # @param conn [Y2Network::Conn] Connection name to remove
      def remove(conn)
        ifcfg = Y2Network::Sysconfig::InterfaceFile.find(conn.interface)
        ifcfg&.remove
        Yast::Host.remove_ip(conn.ip.address.address.to_s) if conn.ip
      end

    private

      # Returns the class to handle a given interface type
      #
      # @param type [Y2Network::InterfaceType] Interface type
      # @return [Class] A class which belongs to the ConnectionConfigWriters module
      def find_handler_class(type)
        require "y2network/sysconfig/connection_config_writers/#{type.file_name}"
        ConnectionConfigWriters.const_get(type.class_name)
      rescue LoadError, NameError => e
        log.info "Unknown connection type: '#{type}'. " \
                 "Connection handler could not be loaded: #{e.message}"
        nil
      end
    end
  end
end
