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

require "y2network/wicked/connection_config_writers/base"

module Y2Network
  module Wicked
    module ConnectionConfigWriters
      # This class is responsible for writing the information from a ConnectionConfig::Wireless
      # object to the underlying system.
      class Wireless < Base
        # @see Y2Network::ConnectionConfigWriters::Base#update_file
        def update_file(conn)
          file.wireless_ap = conn.ap
          file.wireless_ap_scanmode = conn.ap_scanmode
          file.wireless_essid = conn.essid
          file.wireless_mode = conn.mode
          file.wireless_nwid = conn.nwid
          file.wireless_channel = conn.channel
          file.wireless_rate = conn.bitrate
          write_auth_settings(conn) if conn.auth_mode
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
          file.wireless_eap_auth = conn.eap_auth
          file.wireless_wpa_password = conn.wpa_password
          file.wireless_wpa_identity = conn.wpa_identity
          file.wireless_ca_cert = conn.ca_cert
          file.wireless_wpa_anonid = conn.wpa_anonymous_identity if conn.eap_mode == "TTLS"
          file.wireless_client_cert = conn.client_cert if conn.eap_mode == "TLS"
          file.wireless_client_key = conn.client_key if conn.eap_mode == "TLS"
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
