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

require "yast"
require "y2network/network_manager/connection_config_readers/base"

module Y2Network
  module NetworkManager
    module ConnectionConfigReaders
      # This class is responsible for reading the information from a NetworkManager connection
      # configuration file.
      class Wireless < Base
        DEFAULT_MODE = "managed".freeze
        MODE = { "adhoc" => "ad-hoc", "ap" => "master", "infrastructure" => "managed" }.freeze

        # @see Y2Network::NetworkManager::ConnectionConfigReaders::Base#update_connection_config
        def update_connection_config(conn)
          conn.mtu = file.wifi["mtu"].to_i if file.wifi["mtu"]
          conn.mode = MODE[file.wifi["mode"]] || DEFAULT_MODE
          conn.essid = file.wifi["ssid"]
          add_auth_settings(conn)
        end

      private

        # Determines the auth_mode from the given configuration file
        #
        # @return [Symbol] :open, :shared, :psk or :eap
        def auth_mode
          return :open if file.wifi_security.nil?

          case file.wifi_security["key-mgmt"]
          when "wpa-psk"
            :psk
          when "wpa-eap"
            :eap
          else
            (file.wifi_security["auth-alg"] == "shared") ? :shared : :open
          end
        end

        # Adds authorization settings
        #
        # @param conn [Y2Network::ConnectionConfig::Wireless] Connection to add auth settings to
        def add_auth_settings(conn)
          conn.auth_mode = auth_mode
          meth = "add_#{conn.auth_mode}_auth_settings"
          send(meth, conn) if respond_to?(meth, true)
        end

        # Adds wpa-psk settings
        #
        # @param conn [Y2Network::ConnectionConfig::Wireless] Connection to add auth settings to
        def add_psk_auth_settings(conn)
          conn.auth_mode = :psk
          conn.wpa_password = file.wifi_security["psk"]
        end

        # Adds wpa-eap settings
        #
        # @param conn [Y2Network::ConnectionConfig::Wireless] Connection to add auth settings to
        def add_eap_auth_settings(conn)
          section = file.section_for("802-1x")

          eap_modes = section["eap"]&.split(";") || []
          conn.eap_mode = eap_modes.first.upcase # TODO: should we ignore the rest?
          conn.eap_auth = section["phase2-auth"]
          conn.wpa_anonymous_identity = section["anonymous-identity"] if conn.eap_mode == "TTLS"
          conn.wpa_identity = section["identity"]
          conn.ca_cert = section["ca-cert"]

          conn.wpa_password = section["password"]
          conn.client_cert = section["client-cert"]
          conn.client_key = section["private-key"]
          conn.client_key_password = section["private-key-password"]
        end

        # Adds open authorization settings
        #
        # @param conn [Y2Network::ConnectionConfig::Wireless] Connection to add auth settings to
        def add_open_auth_settings(conn)
          add_wep_keys(conn)
        end

        # Adds shared authorization settings
        #
        # @param conn [Y2Network::ConnectionConfig::Wireless] Connection to add auth settings to
        def add_shared_auth_settings(conn)
          add_wep_keys(conn)
        end

        # Maps wep-type to key type
        WEP_KEY_TYPE_PREFIX = { "1" => "s", "2" => "h" }.freeze

        # Adds wep keys
        #
        # @param conn [Y2Network::ConnectionConfig::Wireless] Connection to add auth settings to
        def add_wep_keys(conn)
          return if file.wifi_security.nil?

          wep_keys = file.wifi_security.data.select { |d| d[:key] =~ /^wep-key\d/ }
          prefix = WEP_KEY_TYPE_PREFIX.fetch(file.wifi_security["wep-key-type"], "s")
          conn.keys = wep_keys.map { |k| "#{prefix}:#{k[:value]}" }
        end
      end
    end
  end
end
