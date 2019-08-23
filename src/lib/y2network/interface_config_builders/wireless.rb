require "yast"
require "forwardable"
require "y2network/config"
require "y2network/interface_config_builder"

module Y2Network
  module InterfaceConfigBuilders
    # Builder for wireless configuration. Many methods delegated to ConnectionConfig::Wireless
    class Wireless < InterfaceConfigBuilder
      extend Forwardable
      include Yast::Logger

      def initialize(config: nil)
        super(type: InterfaceType::WIRELESS, config: config)
      end

      def mode
        select_backend(
          @config["WIRELESS_MODE"],
          @connection_config.mode
        )
      end

      def mode=(mode)
        @config["WIRELESS_MODE"] = mode
        @connection_config.mode = mode
      end

      def essid
        select_backend(
          @config["WIRELESS_ESSID"],
          @connection_config.essid
        )
      end

      def essid=(value)
        @config["WIRELESS_ESSID"] = value
        @connection_config.essid = value
      end

      def auth_modes
        Yast::LanItems.wl_auth_modes
      end

      def auth_mode
        select_backend(
          @config["WIRELESS_AUTH_MODE"],
          @connection_config.auth_mode
        )
      end

      def auth_mode=(mode)
        @config["WIRELESS_AUTH_MODE"] = mode
        @connection_config.auth_mode = mode
      end

      def eap_mode
        select_backend(
          @config["WPA_EAP_MODE"],
          @connection_config.eap_mode
        )
      end

      def eap_mode=(mode)
        @config["WIRELESS_EAP_MODE"] = mode
        @connection_config.eap_mode = mode
      end

      def access_point
        select_backend(
          @config["WIRELESS_AP"],
          @connection_config.ap
        )
      end

      def access_point=(value)
        @config["WIRELESS_AP"] = value
        @connection_config.ap = value
      end

      # TODO: select backend? probably not needed as we will merge it when new backend will be already ready
      def_delegators :@connection_config,
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
