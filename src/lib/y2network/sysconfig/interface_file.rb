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
  module Sysconfig
    # This class represents a sysconfig file containing an interface configuration
    #
    # @example Finding the file for a given interface
    #   file = Y2Network::Sysconfig::InterfaceFile.find("wlan0")
    #   file.wireless_essid #=> "dummy"
    class InterfaceFile
      # @return [String] Interface name
      class << self
        SYSCONFIG_NETWORK_DIR = Pathname.new("/etc/sysconfig/network").freeze

        # Finds the ifcfg-* file for a given interface
        #
        # @param interface [String] Interface name
        # @return [Sysconfig::InterfaceFile,nil] Sysconfig
        def find(interface)
          return nil unless Yast::FileUtils.Exists(SYSCONFIG_NETWORK_DIR.join("ifcfg-#{interface}").to_s)
          new(interface)
        end

        # Defines a parameter
        #
        # This method adds a pair of methods to get and set the parameter's value.
        #
        # @param param_name [Symbol] Parameter name
        # @param type       [Symbol] Type to be used (:string, :integer, :symbol, :ipaddr)
        def define_parameter(param_name, type = :string)
          params << param_name

          define_method param_name do
            return @values[param_name] if @values.key?(param_name)
            value = fetch(param_name.to_s.upcase)
            send("value_as_#{type}", value)
          end

          define_method "#{param_name}=" do |value|
            @values[param_name] = value
          end
        end

        # Defines an array parameter
        #
        # This method adds a pair of methods to get and set the parameter's values.
        #
        # @param param_name [Symbol] Parameter name
        # @param limit      [Integer] Maximum array size
        # @param type       [Symbol] Type to be used (:string, :integer, :symbol, :ipaddr)
        def define_array_parameter(param_name, limit, type = :string)
          params << param_name

          define_method "#{param_name}s" do
            return @values[param_name] if @values.key?(param_name)
            key = param_name.to_s.upcase
            values = [fetch(key)]
            values += Array.new(limit) do |idx|
              value = fetch("#{key}_#{idx}")
              next if value.nil?
              send("value_as_#{type}", value)
            end
            values.compact
          end

          define_method "#{param_name}s=" do |value|
            @values[param_name] = value
          end
        end

        # Known configuration attributes/parameters
        #
        # A parameter is defined by using {define_parameter} or {define_array_parameter} methods.
        #
        # @return [Array<Symbol>]
        def params
          @params ||= []
        end
      end

      # @return [String] Interface's name
      attr_reader :interface

      # !@attribute [r] ipaddr
      #   return [IPAddr] IP address
      define_parameter(:ipaddr, :ipaddr)

      # !@attribute [r] name
      #   return [String] Interface's description (e.g., "Ethernet Card 0")
      define_parameter(:name, :string)

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

      # @return [Integer] Number of supported keys
      SUPPORTED_KEYS = 4

      define_array_parameter(:wireless_key, SUPPORTED_KEYS, :string)

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
      # @param interface [String] Interface interface
      def initialize(interface)
        @interface = interface
        @values = {}
      end

      SYSCONFIG_NETWORK_PATH = Pathname.new("/etc").join("sysconfig", "network").freeze

      # Returns the file path
      #
      # @return [Pathname]
      def path
        SYSCONFIG_NETWORK_PATH.join("ifcfg-#{interface}")
      end

      # Returns the IP address if defined
      #
      # @return [IPAddr,nil] IP address or nil if it is not defined
      def ip_address
        str = fetch("IPADDR")
        str.nil? || str.empty? ? nil : IPAddr.new(str)
      end
      alias_method :ip_address, :ipaddr

      # Fetches a key
      #
      # @param key [String] Interface key
      # @return [Object] Value for the given key
      def fetch(key)
        path = Yast::Path.new(".network.value.\"#{interface}\".#{key}")
        Yast::SCR.Read(path)
      end

      # Writes the changes to the file
      #
      # @note Writes only changed values, keeping the rest as they are.
      def save
        @values.each do |key, value|
          normalized_key = key.upcase
          if value.is_a?(Array)
            write_array(normalized_key, value)
          else
            write(normalized_key, value)
          end
        end
        Yast::SCR.Write(Yast::Path.new(".network"), nil)
      end

      # Determines the interface's type
      #
      # @todo Borrow logic from https://github.com/yast/yast-yast2/blob/6f7a789d00cd03adf62e00da34720f326f0e0633/library/network/src/modules/NetworkInterfaces.rb#L291
      #
      # @return [Symbol] Interface's type depending on the file values
      def type
        :eth
      end

      # Empties all known values
      #
      # This idea is to use this method to clear all unneeded values from interface files.
      def clean
        @values = self.class.params.each_with_object({}) { |e, h| h[e] = nil }
      end

    private

      # Converts the value into a string (or nil if empty)
      #
      # @param [String] value
      # @return [String,nil]
      def value_as_string(value)
        value.nil? || value.empty? ? nil : value
      end

      # Converts the value into an integer (or nil if empty)
      #
      # @param [String] value
      # @return [Integer,nil]
      def value_as_integer(value)
        value.nil? || value.empty? ? nil : value.to_i
      end

      # Converts the value into a symbol (or nil if empty)
      #
      # @param [String] value
      # @return [Symbol,nil]
      def value_as_symbol(value)
        value.nil? || value.empty? ? nil : value.to_sym
      end

      # Converts the value into a IPAddr (or nil if empty)
      #
      # @param [String] value
      # @return [IPAddr,nil]
      def value_as_ipaddr(value)
        value.nil? || value.empty? ? nil : IPAddr.new(value)
      end

      # Writes an array as a value for a given key
      #
      # @param key    [Symbol] Key
      # @param values [Array<#to_s>] Values to write
      def write_array(key, values)
        values.each_with_index do |value, idx|
          write("#{key}_#{idx}", value)
        end
      end

      # Writes the value for a given key
      #
      # @param key   [Symbol] Key
      # @param value [#to_s] Value to write
      def write(key, value)
        raw_value = value ? value.to_s : nil
        path = Yast::Path.new(".network.value.\"#{interface}\".#{key}")
        Yast::SCR.Write(path, raw_value)
      end
    end
  end
end
