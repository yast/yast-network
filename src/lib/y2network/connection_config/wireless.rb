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

require "y2network/connection_config/base"
require "yast2/equatable"

module Y2Network
  module ConnectionConfig
    # Configuration for wireless connections
    class Wireless < Base
      include Yast2::Equatable

      # wireless options
      #
      # FIXME: Consider an enum
      # @return [String] (ad-hoc, managed, master)
      attr_reader :mode
      # @return [String]
      attr_accessor :essid
      # @return [String] Network ID
      attr_accessor :nwid
      # @return [Symbol] Authorization mode (:open, :shared, :psk, :eap)
      attr_accessor :auth_mode
      # FIXME: Consider moving keys to different classes.
      # @return [String] WPA preshared key
      attr_accessor :wpa_psk
      # @return [Integer]
      attr_accessor :key_length
      # @return [Array<String>] WEP keys
      attr_accessor :keys
      # @return [Integer] default WEP key
      attr_accessor :default_key
      # @return [String]
      attr_accessor :nick # TODO: what it is? identity?
      # @return [String]
      attr_accessor :eap_mode
      # @return [String]
      attr_accessor :eap_auth
      # @return [Integer, nil]
      attr_accessor :channel
      # @return [Integer]
      attr_accessor :frequency
      # @return [Float, nil] bitrate limitation in Mb/s or nil for automatic
      attr_accessor :bitrate
      # @return [String]
      attr_accessor :ap
      # FIXME: Consider an enum
      # @return [Integer] (0, 1, 2)
      attr_accessor :ap_scanmode
      # TODO: unify psk and password and write correct one depending on mode
      # @return [String]
      attr_accessor :wpa_password
      # @return [String]
      attr_accessor :wpa_identity
      # @return [String] initial identity used for creating tunnel
      attr_accessor :wpa_anonymous_identity
      # @return [String] ca certificate used to sign server certificate
      attr_accessor :ca_cert
      # @return [String] client certificate used to login for TLS
      attr_accessor :client_cert
      # @return [String] client private key used to encrypt for TLS
      attr_accessor :client_key
      # @return [String] client private key password
      attr_accessor :client_key_password
      alias_method :super_inspect, :inspect

      def initialize
        super

        self.mode = "managed"
        self.essid = ""
        self.nwid = ""
        self.auth_mode = :open
        self.wpa_psk = ""
        self.key_length = 128
        self.keys = []
        self.default_key = 0
        self.eap_mode = "PEAP"
        self.eap_auth = "mschapv2"
        self.ap_scanmode = 1
        # For WIFI DHCP makes more sense as majority of wifi routers act as dhcp servers
        self.bootproto = BootProtocol::DHCP
      end

      eql_attr :mode, :essid, :nwid, :auth_mode, :wpa_psk, :key_length, :keys, :default_key, :nick,
        :eap_mode, :eap_auth, :channel, :frequency, :bitrate, :ap, :ap_scanmode, :wpa_password,
        :wpa_identity, :wpa_anonymous_identity, :ca_cert, :client_cert, :client_key,
        :client_key_password

      # @param wireless_mode [String]
      def mode=(wireless_mode)
        @mode = wireless_mode.to_s.downcase
      end

      # Convenience method to check whether there are some WEP key defined
      #
      # @return [Boolean] return true if there is at least one not empty key
      def keys?
        !(keys || []).compact.all?(&:empty?)
      end

      # Return a clone of this object with all sensitive fields (passwords etc.) obscured.
      # Use this for log output to avoid leaking passwords.
      def sanitized
        san = dup
        san.wpa_psk = sanitized_field(san.wpa_psk)
        san.wpa_password = sanitized_field(san.wpa_password)
        san.client_key_password = sanitized_field(san.client_key_password)

        san
      end

      # Sanitize one field if it is non-nil and non-empty.
      def sanitized_field(orig)
        return orig if orig.nil? || orig.empty?

        "<sanitized>".freeze
      end

      def inspect
        sanitized.super_inspect
      end
    end
  end
end
