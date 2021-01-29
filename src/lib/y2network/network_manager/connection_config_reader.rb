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
    # Reads a connection configuration from a given file
    class ConnectionConfigReader
      # TODO: make this signature consistent with Wicked::ConnectionConfigReader
      def read(file)
        file.load
        handler_class = find_handler_class(file.type)
        return nil if handler_class.nil?

        handler_class.new(file).connection_config
      end

    private

      # Returns the class to handle a given interface type
      #
      # @param type [InterfaceType] interface type
      # @return [Class] A class which belongs to the ConnectionConfigReaders module
      def find_handler_class(type)
        require "y2network/network_manager/connection_config_readers/#{type.file_name}"
        ConnectionConfigReaders.const_get(type.class_name)
      rescue LoadeError, NameError => e
        log.info "Unknown connection type: '#{type}'. " \
                 "Connection handler could not be loaded: #{e.message}"
      end
    end
  end
end
