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
Yast.import "NetworkInterfaces"

module Y2Network
  module ConfigReader
    module ConnectionConfig
      class Sysconfig
        # Constructor
        #
        # @param interface [String] Interface name
        # @return [Y2Network::SysconfigInterfaceFile]
        def read(interface)
          type = find_type_for(interface)
          handler_class = find_handler_class(type)
          if handler_class.nil?
            log.info "Unknown connection type: '#{type}'"
            return nil
          end
          file = Y2Network::SysconfigInterfaceFile.new(interface.name)
          handler_class.new(file).connection_config
        end

      private

        # Determines the type of the connection using the name
        #
        # If the interface does not contain information about the type, it will rely on
        # NetworkInterfaces#GetTypeFromSysfs.
        #
        # @todo Improve detection logic according to NetworkInterfaces#GetTypeFromIfcfgOrName.
        #
        # @param interface [Interface] Interface to seach the type for
        # @return [Symbol]
        def find_type_for(interface)
          return interface.type if interface.type
          type = Yast::NetworkInterfaces.GetTypeFromSysfs(interface.name)
          type.nil? ? :eth : type.to_sym
        end

        def find_handler_class(type)
          require "y2network/config_reader/connection_config/sysconfig_handlers/#{type}"
          SysconfigHandlers.const_get(type.to_s.capitalize)
        rescue LoadError
          nil
        end
      end
    end
  end
end
