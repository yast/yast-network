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

require "y2network/sysconfig/connection_config_readers/base"
require "y2network/connection_config/wireless"
require "y2network/boot_protocol"
require "y2network/startmode"

module Y2Network
  module Sysconfig
    module ConnectionConfigReaders
      # This class is able to build a ConnectionConfig::Wireless object given a
      # Sysconfig::InterfaceFile object.
      class Wireless < Base
        # Returns a wireless connection configuration
        #
        # @return [ConnectionConfig::Wireless]
        def connection_config
          Y2Network::ConnectionConfig::Wireless.new.tap do |conn|
            conn.ap = file.wireless_ap
            conn.ap_scanmode = file.wireless_ap_scanmode
            conn.auth_mode = file.wireless_auth_mode
            conn.bootproto = BootProtocol.from_name(file.bootproto || "static")
            conn.default_key = file.wireless_default_key
            conn.description = file.name
            conn.eap_auth = file.wireless_eap_auth
            conn.eap_mode = file.wireless_eap_mode
            conn.essid = file.wireless_essid
            conn.interface = file.interface
            conn.ip_configs = ip_configs
            conn.key_length = file.wireless_key_length
            conn.keys = wireless_keys
            conn.mode = file.wireless_mode
            conn.nwid = file.wireless_nwid
            conn.startmode = Startmode.create(file.startmode || "manual")
            conn.startmode.priority = file.ifplugd_priority if conn.startmode.name == "ifplugd"
            conn.wpa_password = file.wireless_wpa_password
            conn.wpa_psk = file.wireless_wpa_psk
          end
        end

      private

        # Max number of wireless keys
        MAX_WIRELESS_KEYS = 4

        # Reads the array of wireless keys from the file
        def wireless_keys
          (0..MAX_WIRELESS_KEYS - 1).map { |i| file.wireless_keys["_#{i}"] }
        end
      end
    end
  end
end
