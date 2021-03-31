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

require "yast"
require "cfa/nm_connection"
require "pathname"

Yast.import "Installation"

module Y2Network
  module NetworkManager
    class ConnectionConfigWriter
      include Yast::Logger

      # @param conn [ConnectionConfig::Base] Connection configuration to be
      #   written
      # @param old_conn [ConnectionConfig::Base] Original connection
      #   configuration
      # @param opts [Hash] writer options
      def write(conn, old_conn = nil, opts = {})
        return if conn == old_conn

        file = CFA::NmConnection.for(conn)
        handler_class = find_handler_class(conn.type)
        return nil if handler_class.nil?

        if file.exist?
          file.load
        else
          ensure_permissions(file.file_path)
        end

        handler_class.new(file).write(conn, opts)
        file.save
      end

    private

      # Convenience method to ensure the new configuration file permissions
      #
      # @param path [Pathname] connection configuration file path
      def ensure_permissions(path)
        final_path = ::File.join(Yast::WFM.scr_root, path)

        ::FileUtils.touch(final_path)
        ::File.chmod(0o600, final_path)
      end

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
