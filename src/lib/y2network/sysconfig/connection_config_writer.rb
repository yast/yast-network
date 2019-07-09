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

module Y2Network
  module Sysconfig
    class ConnectionConfigWriter
      include Yast::Logger

      # Writes connection config to the underlying system
      #
      # @param conn [Y2Network::ConnectionConfig::Base] Connection configuration to write
      def write(conn)
        file = Y2Network::Sysconfig::InterfaceFile.new(conn.interface)
        handler_class = find_handler_class(conn.type.short_name)
        return nil if handler_class.nil?
        file.clean
        handler_class.new(file).write(conn)
        file.save
      end

    private

      # Returns the class to handle a given interface type
      #
      # @param type [Symbol]
      # @return [Class] A class which belongs to the ConnectionConfigWriters module
      def find_handler_class(type)
        require "y2network/sysconfig/connection_config_writers/#{type}"
        ConnectionConfigWriters.const_get(type.to_s.capitalize)
      rescue LoadError, NameError => e
        log.info "Unknown connection type: '#{type}'. " \
                 "Connection handler could not be loaded: #{e.message}"
        nil
      end
    end
  end
end
