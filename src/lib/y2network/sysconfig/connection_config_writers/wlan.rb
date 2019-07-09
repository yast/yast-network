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
module Y2Network
  module Sysconfig
    module ConnectionConfigWriters
      # This class is responsible for writing the information from a ConnectionConfig::Wireless
      # object to the underlying system.
      class Wlan
        # @return [Y2Network::Sysconfig::InterfaceFile]
        attr_reader :file

        def initialize(file)
          @file = file
        end

        # Writes connection information to the interface configuration file
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write(conn)
          file.bootproto = conn.bootproto
          file.ipaddr = conn.ip_address
          file.name = conn.description
          file.startmode = conn.startmode
          file.wireless_ap = conn.ap
          file.wireless_ap_scanmode = conn.ap_scanmode
          file.wireless_essid = conn.essid
          file.wireless_mode = conn.mode
          file.wireless_nwid = conn.nwid
          write_auth_settings(conn) if conn.auth_mode
          file
        end

      private

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
          file.wireless_auth_mode = conn.auth_mode || :open
          meth = "write_#{conn.auth_mode}_auth_settings".to_sym
          send(meth, conn) if respond_to?(meth, true)
        end

        # Writes autentication settings for WPA-EAP networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_eap_auth_settings(conn)
          file.wireless_eap_mode = conn.eap_mode
          file.wireless_wpa_password = conn.wpa_password
        end

        # Writes autentication settings for WPA-PSK networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_psk_auth_settings(conn)
          file.wireless_wpa_psk = conn.wpa_psk
        end

        # Writes autentication settings for WEP networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_shared_auth_settings(conn)
          file.wireless_keys = conn.keys
          file.wireless_key_length = conn.key_length
          file.wireless_default_key = conn.default_key
        end
      end
    end
  end
end
