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

require "y2network/connection_config/wireless"

module Y2Network
  module ConfigReader
    module ConnectionConfig
      # This class is able to build a ConnectionConfig::Wireless object given a
      # SysconfigInterfaceFile object.
      class SysconfigWireless
        # @return [Y2Network::SysconfigInterfaceFile]
        attr_reader :file

        def initialize(file)
          @file = file
        end

        # Returns an ethernet connection configuration
        #
        # @param name [String] Interface name
        # @return [ConnectionConfig::Ethernet]
        def connection_config
          Y2Network::ConnectionConfig::Wireless.new.tap do |conn|
            conn.interface = file.name
            conn.bootproto = file.fetch("BOOTPROTO").to_sym
            conn.ip_address = file.ip_address
            conn.essid = file.fetch("WIRELESS_ESSID")
            conn.mode = file.fetch("WIRELESS_MODE")
            conn.auth_mode = file.fetch("WIRELESS_AUTH_MODE")
            conn.wpa_psk = file.fetch("WIRELESS_WPA_PSK")
            # TODO: conn.nwid
            conn.wpa_psk = file.fetch("WIRELESS_KEY_LENGTH")
          end
        end
      end
    end
  end
end
