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

require "yast"
require "forwardable"
require "y2network/config"
require "y2network/interface_config_builder"

module Y2Network
  module InterfaceConfigBuilders
    # Builder for wireless configuration. Many methods delegated to ConnectionConfig::Wireless
    # @see ConnectionConfig::Wireless
    class Wireless < InterfaceConfigBuilder
      extend Forwardable
      include Yast::Logger

      def initialize(config: nil)
        super(type: InterfaceType::WIRELESS, config: config)
      end

      def auth_modes
        Yast::LanItems.wl_auth_modes
      end

      def access_point
        @connection_config.ap
      end

      def access_point=(value)
        @connection_config.ap = value
      end

      def_delegators :@connection_config,
        :auth_mode, :auth_mode=,
        :eap_mode, :eap_mode=,
        :mode, :mode=,
        :essid, :essid=,
        :wpa_psk, :wpa_psk=,
        :wpa_password, :wpa_password=,
        :wpa_identity, :wpa_identity=,
        :wpa_anonymous_identity, :wpa_anonymous_identity=,
        :ca_cert, :ca_cert=,
        :client_key, :client_key=,
        :client_cert, :client_cert=,
        :channel, :channel=,
        :bitrate, :bitrate=,
        :ap_scanmode, :ap_scanmode=,
        :keys, :keys=,
        :key_length, :key_length=,
        :default_key, :default_key=
    end
  end
end
