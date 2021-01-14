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

require "cfa/nm_connection"
require "pathname"

module Y2Network
  module NetworkManager
    class ConnectionConfigWriter
      include Yast::Logger

      SYSTEM_CONNECTIONS_PATH = Pathname.new("/etc/NetworkManager/system-connections").freeze
      FILE_EXT = ".nmconnection".freeze

      def write(conn, old_conn = nil)
        return if conn == old_conn

        file = CFA::NmConnection.new(SYSTEM_CONNECTIONS_PATH.join(conn.name).sub_ext(FILE_EXT))
        handler_class = find_handler_class(conn.type)
        return nil if handler_class.nil?

        handler_class.new(file).write(conn)
        file.save
      end

    private

      # Returns the class to handle a given interface type
      #
      # @param type [Y2Network::InterfaceType] Interface type
      # @return [Class] A class which belongs to the ConnectionConfigWriters module
      def find_handler_class(type)
        require "y2network/network_manager/connection_config_writers/#{type.file_name}"
        ConnectionConfigWriters.const_get(type.class_name)
      rescue LoadError, NameError => e
        log.info "Unknown connection type: '#{type}'. " \
                 "Connection handler could not be loaded: #{e.message}"
        nil
      end
    end
  end
end
