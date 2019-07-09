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

require "y2network/connection_config/ethernet"

module Y2Network
  module Sysconfig
    module ConnectionConfigReaders
      # This class is able to build a ConnectionConfig::Ethernet object given a
      # Sysconfig::InterfaceFile object.
      class Eth
        # @return [Y2Network::Sysconfig::InterfaceFile]
        attr_reader :file

        # Constructor
        #
        # @param file [Y2Network::Sysconfig::InterfaceFile] File to get interface configuration from
        def initialize(file)
          @file = file
        end

        # @return [Y2Network::ConnectionConfig::Ethernet]
        def connection_config
          Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
            conn.bootproto = file.bootproto
            conn.description = file.name
            conn.interface = file.interface
            conn.ip_address = file.ip_address
          end
        end
      end
    end
  end
end
