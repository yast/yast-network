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

require "y2network/network_manager/connection_config_writers/base"

module Y2Network
  module NetworkManager
    module ConnectionConfigWriters
      # This class is responsible for writing the information from a ConnectionConfig::Wireless
      # object to the underlying system.
      class Wireless < Base
        MODE = { "ad-hoc" => "ad-hoc", "master" => "ap", "managed" => "infrastructure" }.freeze

        # @see Y2Network::ConnectionConfigWriters::Base#update_file
        def update_file(conn)
          file.connection["type"] = "wifi"
          file.wifi["ssid"] = conn.essid unless conn.essid.to_s.empty?
          file.wifi["mode"] = MODE[conn.mode]
          file.wifi["channel"] = con.channel if conn.channel

          write_auth_settings(conn)
        end

        # Writes autentication settings for WPA-EAP networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_eap_auth_settings(_conn)
        end

        # Writes authentication settings
        #
        # This method relies in `write_*_auth_settings` methods.
        #
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        #
        # @see #write_eap_auth_settings
        # @see #write_psk_auth_settings
        # @see #write_shared_auth_settings
        def write_auth_settings(conn)
          meth = "write_#{conn.auth_mode}_auth_settings".to_sym
          send(meth, conn) if respond_to?(meth, true)
        end

        # Writes autentication settings for WPA-PSK networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_psk_auth_settings(conn)
          file.wifi_security["auth-alg"] = "open"
          file.wifi_security["key-mgmt"] = "wpa-psk"
          file.wifi_security["psk"] = conn.wpa_psk
        end

        # Writes autentication settings for WEP networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_shared_auth_settings(_conn)
        end
      end
    end
  end
end
