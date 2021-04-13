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

module Y2Network
  module Wicked
    # Reads a connection configuration for a given interface
    class ConnectionConfigReader
      include Yast::Logger

      # Constructor
      #
      # @param name [String] Interface name
      # @param type [InterfaceType, string, nil] Interface type; if the type is unknown,
      #   `nil` can be used and it will be guessed from the configuration file if possible.
      #
      # @return [Y2Network::ConnectionConfig::Base]
      def read(name, type, errors_list)
        file = CFA::InterfaceFile.new(name)
        file.load
        handler_class = find_handler_class(type || file.type)
        return nil if handler_class.nil?

        handler_class.new(file, errors_list).connection_config
      end

    private

      # Returns the class to handle a given interface type
      #
      # @param type [String, InterfaceType, nil] interface type or its short name
      # @return [Class] A class which belongs to the ConnectionConfigReaders module
      def find_handler_class(type)
        return unless type

        if !type.is_a?(InterfaceType)
          t = InterfaceType.from_short_name(type) or
            raise "Unknown type #{type.inspect} #{type.class.inspect}"
          type = t
        end
        require "y2network/wicked/connection_config_readers/#{type.file_name}"
        ConnectionConfigReaders.const_get(type.class_name)
      rescue LoadError, NameError => e
        log.info "Unknown connection type: '#{type}'. " \
                 "Connection handler could not be loaded: #{e.message}"
        nil
      end
    end
  end
end
