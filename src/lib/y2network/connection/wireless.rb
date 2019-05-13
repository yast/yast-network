require "y2network/connection/connection"

module Y2Network
  module Connection
    class Wireless < Connection
      # wireless options
      # @return [String]
      attr_accessor :mode
      # @return [String]
      attr_accessor :essid
      # @return [Integer]
      attr_accessor :nwid
      # @return [String]
      attr_accessor :auth_mode
      # FIXME: Consider moving keys to different classes.
      # @return [String]
      attr_accessor :wpa_psk
      # @return [Integer]
      attr_accessor :key_length
      # @return [Array<String>] WEP keys
      attr_accessor :keys
      # @return [String] default WEP key
      attr_accessor :default_key
      # @return [String]
      attr_accessor :nick

      # @return [Hash<String, String>]
      attr_accessor :wpa_eap
      # @return [Integer]
      attr_accessor :channel
      # @return [Integer]
      attr_accessor :frequency
      # @return [Integer]
      attr_accessor :bitrate
      # @return [String]
      attr_accessor :accesspoint
      # @return [Boolean]
      attr_accessor :power
      # @return [String]
      attr_accessor :ap_scanmode
    end
  end
end
