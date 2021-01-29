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
        DEFAULT_MODE = "infrastructure".freeze
        MODE = { "ad-hoc" => "ad-hoc", "master" => "ap", "managed" => "infrastructure" }.freeze

        # @see Y2Network::ConnectionConfigWriters::Base#update_file
        def update_file(conn)
          file.connection["type"] = "wifi"
          file.wifi["ssid"] = conn.essid unless conn.essid.to_s.empty?
          file.wifi["mode"] = MODE[conn.mode] || DEFAULT_MODE
          file.wifi["channel"] = con.channel if conn.channel

          write_auth_settings(conn)
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
        # @see #write_open_auth_settings
        # @see #write_shared_auth_settings
        def write_auth_settings(conn)
          auth_mode = conn.auth_mode || :open
          meth = "write_#{auth_mode}_auth_settings".to_sym
          send(meth, conn) if respond_to?(meth, true)
        end

        # Writes autentication settings for WPA-EAP networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_eap_auth_settings(conn)
          # FIXME: incomplete
          file.wifi_security["key-mgmt"] = "wpa-eap"
          section = file.section_for("802-1x")

          section["eap"] = conn.eap_mode.downcase if conn.eap_mode
          section["phase2-auth"] = conn.eap_auth if conn.eap_auth
          section["password"] = conn.wpa_password if conn.wpa_password && conn.eap_mode != "TLS"
          section["anonymous-identity"] = conn.wpa_anonymous_identity if conn.eap_mode == "TTLS"
          section["identity"] = conn.wpa_identity if conn.wpa_identity
          section["ca-cert"] = conn.ca_cert if conn.ca_cert

          return unless conn.eap_mode == "TLS"

          section["client-cert"] = conn.client_cert
          section["private-key"] = conn.client_key
          section["private-key-password"] = conn.client_key_password
        end

        # Writes autentication settings for WPA-PSK networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_psk_auth_settings(conn)
          file.wifi_security["key-mgmt"] = "wpa-psk"
          file.wifi_security["auth-alg"] = "open"
          file.wifi_security["psk"] = conn.wpa_psk
        end

        # Writes autentication settings for WEP networks
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_wep_auth_settings(conn)
          file.wifi_security["key-mgmt"] = "none"
          default_key_idx = conn.default_key || 0
          file.wifi_security["wep-tx-keyidx"] = default_key_idx.to_s if !default_key_idx.zero?
          conn.keys.each_with_index do |v, i|
            next if v.to_s.empty?

            file.wifi_security["wep-key#{i}"] = v.gsub(/^[sh]:/, "")
          end
          passphrase_used = conn.keys[default_key_idx].to_s.start_with?(/h:/)
          # see https://developer.gnome.org/libnm/stable/NMSettingWirelessSecurity.html#NMWepKeyType
          # 1: Hex or ASCII, 2: 104/128-bit Passphrase
          file.wifi_security["wep-key-type"] = passphrase_used ? "2" : "1"

          true
        end

        # Writes autentication settings for WEP networks (open auth)
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_open_auth_settings(conn)
          return if (conn.keys || []).compact.all?(&:empty?)

          file.wifi_security["auth-alg"] = "open"
          write_wep_auth_settings(conn)
        end

        # Writes autentication settings for WEP networks (shared auth)
        #
        # @param conn [Y2Network::ConnectionConfig::Base] Configuration to write
        def write_shared_auth_settings(conn)
          return if (conn.keys || []).compact.all?(&:empty?)

          file.wifi_security["auth-alg"] = "shared"
          write_wep_auth_settings(conn)
        end
      end
    end
  end
end
