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
require "pathname"
require "ipaddr"

module Y2Network
  # This class represents a sysconfig file containing an interface configuration
  #
  # @example Finding the file for a given interface
  #   file = Y2Network::SysconfigInterfaceFile.find("wlan0")
  #   file.wireless_essid #=> "dummy"
  class SysconfigInterfaceFile
    # @return [String] Interface name
    class << self
      SYSCONFIG_NETWORK_DIR = Pathname.new("/etc/sysconfig/network").freeze

      # Finds the ifcfg-* file for a given interface
      #
      # @param name [String] Interface name
      # @return [SysconfigInterfaceFile,nil] Sysconfig
      def find(name)
        return nil unless Yast::FileUtils.Exists(SYSCONFIG_NETWORK_DIR.join("ifcfg-#{name}").to_s)
        new(name)
      end

      def define_parameter(name, type = :string)
        define_method name do
          value = fetch(name.to_s.upcase)
          send("value_as_#{type}", value)
        end
      end
    end

    attr_reader :name

    # !@attribute [r] bootproto
    #   return [Symbol] Set up protocol (:static, :dhcp, :dhcp4, :dhcp6, :autoip, :dhcp+autoip,
    #                   :auto6, :6to4, :none)
    define_parameter(:bootproto, :symbol)

    # !@attribute [r] bootproto
    #   return [Symbol] When the interface should be set up (:manual, :auto, :hotplug, :nfsroot, :off)
    define_parameter(:startmode, :symbol)

    # !@attribute [r] wireless_key_length
    #   @return [Integer] Length in bits for all keys used
    define_parameter(:wireless_key_length, :integer)

    # !@attribute [r] wireless_default_key
    #   @return [Integer] Index of the default key
    #   @see #wireless_keys
    define_parameter(:wireless_default_key, :integer)

    # !@attribute [r] wireless_essid
    #   @return [String] Wireless SSID/ESSID
    define_parameter(:wireless_essid)

    # !@attribute [r] wireless_auth_mode
    #   @return [Symbol] Wireless authorization mode (:open, :shared, :psk, :eap)
    define_parameter(:wireless_auth_mode, :symbol)

    # @!attribute [r] wireless_mode
    #  @return [Symbol] Operating mode for the device (:managed, :ad_hoc or :master)
    define_parameter(:wireless_mode, :symbol)

    # @!attribute [r] wireless_wpa_password
    #  @return [String] Password as configured on the RADIUS server (for WPA-EAP)
    define_parameter(:wireless_wpa_password)

    # @!attribute [r] wireless_wpa_driver
    #   @return [String] Driver to be used by the wpa_supplicant program
    define_parameter(:wireless_wpa_driver)

    # @!attribute [r] wireless_wpa_psk
    #   @return [String] WPA preshared key (for WPA-PSK)
    define_parameter(:wireless_wpa_psk)

    # @!attribute [r] wireless_eap_mode
    #   @return [String] WPA-EAP outer authentication method
    define_parameter(:wireless_eap_mode)

    # @!attribute [r] wireless_eap_auth
    #   @return [String] WPA-EAP inner authentication with TLS tunnel method
    define_parameter(:wireless_eap_auth)

    # @!attribute [r] wireless_ap_scanmode
    #   @return [String] SSID scan mode ("0", "1" and "2")
    define_parameter(:wireless_ap_scanmode)

    # @!attribute [r] wireless_ap
    #   @return [String] AP MAC address
    define_parameter(:wireless_ap)

    # @!attribute [r] wireless_channel
    #   @return [Integer] Wireless channel
    define_parameter(:wireless_channel)

    # @!attribute [r] wireless_nwid
    #   @return [String] Network ID
    define_parameter(:wireless_nwid)

    # Constructor
    #
    # @param name [String] Interface name
    def initialize(name)
      @name = name
    end

    # Returns the IP address if defined
    #
    # @return [IPAddr,nil] IP address or nil if it is not defined
    def ip_address
      str = fetch("IPADDR")
      str.empty? ? nil : IPAddr.new(str)
    end

    # @return [Integer] Number of supported keys
    SUPPORTED_KEYS = 4

    # List of wireless keys
    #
    # @return [Array<String>] Wireless keys
    def wireless_keys
      keys = [fetch("WIRELESS_KEY")]
      keys += Array.new(SUPPORTED_KEYS) { |i| fetch("WIRELESS_KEY_#{i}") }
      keys.compact
    end

    # Fetches a key
    #
    # @param key [String] Interface key
    # @return [Object] Value for the given key
    def fetch(key)
      path = Yast::Path.new(".network.value.\"#{name}\".#{key}")
      Yast::SCR.Read(path)
    end

  private

    # Converts the value into a string (or nil if empty)
    #
    # @param [String] value
    # @return [String,nil]
    def value_as_string(value)
      value.empty? ? nil : value
    end

    # Converts the value into an integer (or nil if empty)
    #
    # @param [String] value
    # @return [Integer,nil]
    def value_as_integer(value)
      value.empty? ? nil : value.to_i
    end

    # Converts the value into a symbol (or nil if empty)
    #
    # @param [String] value
    # @return [Symbol,nil]
    def value_as_symbol(value)
      value.empty? ? nil : value.to_sym
    end
  end
end
