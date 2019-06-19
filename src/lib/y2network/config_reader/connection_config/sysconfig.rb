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

require "y2network/sysconfig_interface_file"

module Y2Network
  module ConfigReader
    module ConnectionConfig
      # Reads a connection configuration for a given interface
      class Sysconfig
        include Yast::Logger

        # Constructor
        #
        # @param name [String] Interface name
        # @param type [Symbol,nil] Interface type (:eth, :wlan, etc.); if the type is unknown,
        #   `nil` can be used and it will be guessed from the configuration file is possible.
        #
        # @return [Y2Network::ConnectionConfig::Base]
        def read(name, type)
          file = Y2Network::SysconfigInterfaceFile.new(name)
          handler_class = find_handler_class(type || file.type)
          return nil if handler_class.nil?
          handler_class.new(file).connection_config
        end

      private

        def find_handler_class(type)
          require "y2network/config_reader/connection_config/sysconfig_handlers/#{type}"
          SysconfigHandlers.const_get(type.to_s.capitalize)
        rescue LoadError, NameError => e
          log.info "Unknown connection type: '#{type}'. " \
                   "Connection handler could not be loaded: #{e.message}"
          nil
        end
      end
    end
  end
end
