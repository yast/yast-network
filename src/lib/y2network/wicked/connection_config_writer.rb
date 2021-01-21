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

require "cfa/interface_file"
require "cfa/routes_file"

Yast.import "Host"
Yast.import "Mode"

module Y2Network
  module Wicked
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

        file = CFA::InterfaceFile.new(conn.interface)
        handler_class = find_handler_class(conn.type)
        return nil if handler_class.nil?

        file.clean
        remove(old_conn) if old_conn
        handler_class.new(file).write(conn)
        file.save
      end

      # Removes connection config from the underlying system
      #
      # @param conn [Y2Network::Conn] Connection name to remove
      def remove(conn)
        ifcfg = CFA::InterfaceFile.find(conn.interface)
        ifcfg&.remove
        # During an autoinstallation do not remove /etc/hosts entries
        # associated with the static IP address (bsc#1173213).
        # The hook or original behavior was introduced because of (bsc#951330)
        Yast::Host.remove_ip(conn.ip.address.address.to_s) if !Yast::Mode.auto && conn.ip
      end

    private

      # Returns the class to handle a given interface type
      #
      # @param type [Y2Network::InterfaceType] Interface type
      # @return [Class] A class which belongs to the ConnectionConfigWriters module
      def find_handler_class(type)
        require "y2network/wicked/connection_config_writers/#{type.file_name}"
        ConnectionConfigWriters.const_get(type.class_name)
      rescue LoadError, NameError => e
        log.info "Unknown connection type: '#{type}'. " \
                 "Connection handler could not be loaded: #{e.message}"
        nil
      end
    end
  end
end
