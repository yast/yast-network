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
    module ConnectionConfigReaders
      # This is the base class for connection config readers
      class Base
        # @return [Y2Network::Sysconfig::InterfaceFile] Interface's configuration file
        attr_reader :file

        # Constructor
        #
        # @param file [Y2Network::Sysconfig::InterfaceFile] Interface's configuration file
        def initialize(file)
          @file = file
        end

        # Returns the IPs configuration from the file
        #
        # @return [Array<Y2Network::ConnectionConfig::IPAdress>] IP addresses configuration
        # @see Y2Network::ConnectionConfig::IPConfig
        def ip_configs
          file.ipaddrs.map do |id, ip|
            prefix = file.prefixlens[id]
            ip.prefix = prefix if prefix
            Y2Network::ConnectionConfig::IPConfig.new(
              ip,
              id:             id,
              scope:          file.scopes[id],
              label:          file.labels[id],
              remote_address: file.remote_ipaddrs[id],
              broadcast:      file.broadcasts[id]
            )
          end
        end
      end
    end
  end
end
