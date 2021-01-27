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
require "y2network/ip_address"
require "y2network/interface_type"

Yast.import "FileUtils"

module CFA
  # This class represents a sysconfig file containing an interface configuration
  #
  # The configuration is defined by a set of variables that are included in the file.
  # Check ifcfg(5) for further information.
  #
  # @example Finding the file for a given interface
  #   file = CFA::InterfaceFile.find("wlan0")
  #   file.wireless_essid #=> "dummy"
  #
  # ## Multivalued variables
  #
  # When dealing with multivalued variables, values are returned in a hash which
  # indexes are the suffixes. For instance:
  #
  #   IPADDR='192.168.122.1/24'
  #   IPADDR_EXTRA='192.168.123.1/24'
  #   IPADDR_ALT='10.0.0.1/8'
  #
  # @example Reading multivalued variables
  #   file = CFA::InterfaceFile.find("wlan0")
  #   file.ipaddrs #=> { default: #<IPAddr: ...>,
  #     "_EXTRA" => #<IPAddr: ...>, "_ALT" => #<IPAddr: ...> }
  class InterfaceFile
    # Auxiliar class to hold variables definition information
    Variable = Struct.new(:name, :type, :collection?)

    # @return [String] Interface name
    class << self
      SYSCONFIG_NETWORK_DIR = Pathname.new("/etc/sysconfig/network").freeze

      # @return [Regex] expression to filter out invalid ifcfg-* files
      IGNORE_IFCFG_REGEX = /(\.bak|\.orig|\.rpmnew|\.rpmorig|-range|~|\.old|\.scpmbackup)$/.freeze

      # Returns all configuration files
      #
      # @return [Array<InterfaceFile>]
      def all
        Yast::SCR.Dir(Yast::Path.new(".network.section"))
          .reject { |f| IGNORE_IFCFG_REGEX =~ f || f == "lo" }
          .map { |f| find(f) }
          .compact
      end

      # Finds the ifcfg-* file for a given interface
      #
      # @param interface [String] Interface name
      # @return [CFA::InterfaceFile,nil] Interface file
      def find(interface)
        file = new(interface)
        file.exist? ? file : nil
      end

      # Defines a parameter
      #
      # This method registers the parameter and adds a pair of methods to get and set its
      # value.
      #
      # @param param_name [Symbol] Parameter name
      # @param type       [Symbol] Parameter type (:string, :integer, :symbol, :ipaddr)
      def define_variable(param_name, type = :string)
        name = variable_name(param_name)
        variables[name] = Variable.new(name, type, false)

        define_method param_name do
          @values[name]
        end

        define_method "#{param_name}=" do |value|
          # The `value` should be an object which responds to #to_s so its value can be written to
          # the ifcfg file.
          @values[name] = value
        end
      end

      # Defines an array parameter
      #
      # This method registers the parameter and adds a pair of methods to get and set its
      # value. In this case, the parameter is an array.
      #
      # @param param_name [Symbol] Parameter name
      # @param type       [Symbol] Array elements type (:string, :integer, :symbol, :ipaddr)
      def define_collection_variable(param_name, type = :string)
        name = variable_name(param_name)
        variables[name] = Variable.new(name, type, true)

        define_method "#{param_name}s" do
          @values[name]
        end

        define_method "#{param_name}s=" do |value|
          @values[name] = value
        end
      end

      # Known configuration variables
      #
      # A variable is defined by using {define_variable} or {define_collection_variable} methods.
      #
      # @return [Array<Symbol>]
      def variables
        @variables ||= {}
      end

    private

      # Parameter name to internal variable name
      #
      # @param param_name [Symbol]
      # @return [String] Convert a parameter name to the expected internal name
      def variable_name(param_name)
        param_name.to_s.upcase
      end
    end

    # @return [String] Interface's name
    attr_reader :interface

    # !@attribute [r] ipaddr
    #   @return [Y2Network::IPAddress] IP address
    define_collection_variable(:ipaddr, :ipaddr)

    # !@attribute [r] name
    #   @return [String] Interface's description (e.g., "Ethernet Card 0")
    define_variable(:name, :string)

    # !@attribute [r] interfacetype
    #   @return [String] Forced Interface's type (e.g., "dummy")
    define_variable(:interfacetype, :string)

    # !@attribute [r] MTU
    #   @return [String] Max Transmission Unit for the interface
    define_variable(:mtu, :string)

    # !@attribute [r] bootproto
    #   return [String] Set up protocol (static, dhcp, dhcp4, dhcp6, autoip, dhcp+autoip,
    #                   auto6, 6to4, none)
    define_variable(:bootproto)

    # !@attribute [r] bootproto
    #   return [String] When the interface should be set up (manual, auto, hotplug, nfsroot, off,
    #     and ifplugd which is not handled by wicked, but by ifplugd daemon and is not mentioned
    #     in man page)
    define_variable(:startmode)

    # !@attribute [r] labels
    #   @return [Hash] Label to assign to the address
    define_collection_variable(:label, :string)

    # !@attribute [r] remote_ipaddrs
    #   @return [Hash] Remote IP address of a point to point connection
    define_collection_variable(:remote_ipaddr, :ipaddr)

    # !@attribute [r] ifplugd_priority
    #   return [Integer] when startmode is set to ifplugd this defines its priority. Not handled
    #   by wicked, but own daemon. Not documented in man page.
    define_variable(:ifplugd_priority, :symbol)

    # !@attribute [r] broadcasts
    #   @return [Hash] Broadcasts addresses
    define_collection_variable(:broadcast, :ipaddr)

    # !@attribute [r] prefixlens
    #   @return [Hash] Prefixes lengths
    define_collection_variable(:prefixlen, :integer)

    # !@attribute [r] netmasks
    #   @return [Hash] Netmasks
    define_collection_variable(:netmask)

    # !@attribute [r] lladdr
    #   @return [String] Link layer address
    define_variable(:lladdr)

    # !@attribute [r] ethtool_options
    #   @return [String] setting variables on device activation. See man ethtool
    define_variable(:ethtool_options)

    # !@attribute [r] zone
    #   @return [String] assign zone to interface. Extensions then can handle it
    define_variable(:zone)

    # !@attribute [r] wireless_key_length
    #   @return [Integer] Length in bits for all keys used
    define_variable(:wireless_key_length, :integer)

    # !@attribute [r] wireless_keys
    #   @return [Array<String>] List of wireless keys
    define_collection_variable(:wireless_key, :string)

    # !@attribute [r] wireless_default_key
    #   @return [Integer] Index of the default key
    #   @see #wireless_keys
    define_variable(:wireless_default_key, :integer)

    # !@attribute [r] wireless_essid
    #   @return [String] Wireless SSID/ESSID
    define_variable(:wireless_essid)

    # !@attribute [r] wireless_auth_mode
    #   @return [Symbol] Wireless authorization mode (:no-encryption, :open, :sharedkey, :psk,
    #     :eap)
    define_variable(:wireless_auth_mode, :symbol)

    # @!attribute [r] wireless_mode
    #  @return [String] Operating mode for the device (managed, ad-hoc or master)
    define_variable(:wireless_mode, :string)

    # @!attribute [r] wireless_wpa_password
    #  @return [String] Password as configured on the RADIUS server (for WPA-EAP)
    define_variable(:wireless_wpa_password)

    # @!attribute [r] wireless_wpa_anonid
    #  @return [String] anonymous identity used for initial tunnel (TTLS)
    define_variable(:wireless_wpa_anonid)

    # @!attribute [r] wireless_wpa_driver
    #   @return [String] Driver to be used by the wpa_supplicant program
    define_variable(:wireless_wpa_driver)

    # @!attribute [r] wireless_wpa_psk
    #   @return [String] WPA preshared key (for WPA-PSK)
    define_variable(:wireless_wpa_psk)

    # @!attribute [r] wireless_wpa_identity
    #   @return [String] WPA identify
    define_variable(:wireless_wpa_identity)

    # @!attribute [r] wireless_ca_cert
    #   @return [String] CA certificate used to sign server certificate
    define_variable(:wireless_ca_cert)

    # @!attribute [r] wireless_client_cert
    #   @return [String] CA certificate used to sign server certificate
    define_variable(:wireless_client_cert)

    # @!attribute [r] wireless_client_key
    #   @return [String] client private key used for encryption in TLS
    define_variable(:wireless_client_key)

    # @!attribute [r] wireless_client_key_password
    #   @return [String] client private key password used for encryption in TLS
    define_variable(:wireless_client_key_password)

    # @!attribute [r] wireless_eap_mode
    #   @return [String] WPA-EAP outer authentication method
    define_variable(:wireless_eap_mode)

    # @!attribute [r] wireless_eap_auth
    #   @return [String] WPA-EAP inner authentication with TLS tunnel method
    define_variable(:wireless_eap_auth)

    # @!attribute [r] wireless_ap_scanmode
    #   @return [String] SSID scan mode ("0", "1" and "2")
    define_variable(:wireless_ap_scanmode)

    # @!attribute [r] wireless_ap
    #   @return [String] AP MAC address
    define_variable(:wireless_ap)

    # @!attribute [r] wireless_channel
    #   @return [Integer, nil] Wireless channel or nil for auto selection
    define_variable(:wireless_channel, :integer)

    # @!attribute [r] wireless_nwid
    #   @return [String] Network ID
    define_variable(:wireless_nwid)

    # @!attribute [r] wireless_rate
    #   @return [String] Wireless bit rate specification ( Mb/s)
    define_variable(:wireless_rate, :float)

    ## INFINIBAND

    # @!attribute [r] ipoib_mode
    #   @return [String] IPOIB mode ("connected" or "datagram")
    define_variable(:ipoib_mode)

    ## VLAN

    # !@attribute [r] etherdevice
    #   @return [String] Real device for the virtual LAN
    define_variable(:etherdevice)

    # !@attribute [r] vlan_id
    #   @return [String] VLAN ID
    define_variable(:vlan_id, :integer)

    ## BONDING

    # @!attribute [r] bonding_master
    #   @return [String] whether the interface is a bond device or not
    define_variable(:bonding_master)

    # @!attribute [r] bonding_slaves
    #   @return [Hash] Bonding slaves
    define_collection_variable(:bonding_slave)

    # @!attribute [r] bonding_module_opts
    #   @return [String] options for the bonding module ('mode=active-backup
    #                     miimon=100')
    define_variable(:bonding_module_opts)

    ## BRIDGE

    # @!attribute [r] bridge
    #   @return [String] whether the interface is a bridge or not
    define_variable(:bridge)

    # @!attribute [r] bridge_ports
    #   @return [String] interfaces members of the bridge
    define_variable(:bridge_ports)

    # @!attribute [r] bridge_stp
    #   @return [String] Spanning Tree Protocol ("off" or "on")
    define_variable(:bridge_stp)

    # @!attribute [r] bridge_forwarddelay
    #   @return [Integer]
    define_variable(:bridge_forwarddelay, :integer)

    ## TUN / TAP

    # @!attribute [r] tunnel
    #   @return [String] tunnel protocol ("sit", "gre", "ipip", "tun", "tap")
    define_variable(:tunnel)

    # @!attribute [r] tunnel_set_owner
    #   @return [String] tunnel owner
    define_variable(:tunnel_set_owner)

    # @!attribute [r] tunnel_set_group
    #   @return [String] tunnel group
    define_variable(:tunnel_set_group)

    # @!attribute [r] dhclient_set_hostname
    #   @return [String] use hostname from dhcp
    define_variable(:dhclient_set_hostname)

    # Constructor
    #
    # @param interface [String] Interface interface
    def initialize(interface)
      @interface = interface
      @values = collection_variables.each_with_object({}) do |variable, hash|
        hash[variable.name] = {}
      end
    end

    SYSCONFIG_NETWORK_PATH = Pathname.new("/etc").join("sysconfig", "network").freeze

    # Returns the file path
    #
    # @return [Pathname]
    def path
      SYSCONFIG_NETWORK_PATH.join("ifcfg-#{interface}")
    end

    # Loads values from the configuration file
    #
    # @return [Hash<String, Object>] All values from the file
    def load
      @values = self.class.variables.values.each_with_object({}) do |variable, hash|
        meth = variable.collection? ? :fetch_collection : :fetch_scalar
        hash[variable.name] = send(meth, variable.name, variable.type)
      end
    end

    # Writes the changes to the file
    #
    # @note Writes only changed values, keeping the rest as they are.
    def save
      self.class.variables.keys.each do |name|
        value = @values[name]
        meth = value.is_a?(Hash) ? :write_collection : :write_scalar
        send(meth, name, value)
      end
      Yast::SCR.Write(Yast::Path.new(".network"), nil)
    end

    # Determines the interface's type
    #
    # @return [Y2Network::InterfaceType] Interface's type depending on the configuration
    #                                    If particular type cannot be recognized, then
    #                                    ETHERNET is returned (same default as in wicked)
    def type
      type_by_key_value ||
        type_by_key_existence ||
        type_from_interfacetype ||
        type_by_name ||
        Y2Network::InterfaceType::ETHERNET
    end

    # Empties all known values
    #
    # This method clears all values from the file. The idea is to use this method
    # to do some clean-up before writing the final values.
    def clean
      @values = self.class.variables.values.each_with_object({}) do |variable, hash|
        if variable.collection?
          clean_collection(variable.name)
          hash[variable.name] = {}
        else
          write_scalar(variable.name, nil)
          hash[variable.name] = nil
        end
      end

      @defined_variables = nil
    end

    # Removes the file
    def remove
      return unless exist?

      Yast::SCR.Execute(Yast::Path.new(".target.remove"), path.to_s)
    end

    # Determines whether the ifcfg-* file exists
    #
    # @return [Boolean] true if the file exists; false otherwise
    def exist?
      Yast::FileUtils.Exists(path.to_s)
    end

  private

    # Detects interface type according to type specific option and its value
    #
    # @return [Y2Network::InterfaceType, nil] particular type if recognized, nil otherwise
    def type_by_key_value
      return Y2Network::InterfaceType::BONDING if bonding_master == "yes"
      return Y2Network::InterfaceType::BRIDGE if bridge == "yes"
      return Y2Network::InterfaceType.from_short_name(tunnel) if tunnel

      # in relation to original implementation ommited ENCAP option which leads to isdn
      # and PPPMODE which leads to ppp. Neither of this type has been handled as
      # "netcard" - see Yast::NetworkInterfaces for details

      nil
    end

    KEY_TO_TYPE = {
      "ETHERDEVICE"   => Y2Network::InterfaceType::VLAN,
      "WIRELESS_MODE" => Y2Network::InterfaceType::WIRELESS,
      "MODEM_DEVICE"  => Y2Network::InterfaceType::PPP
    }.freeze

    # Detects interface type according to type specific option
    #
    # @return [Y2Network::InterfaceType, nil] particular type if recognized, nil otherwise
    def type_by_key_existence
      key = KEY_TO_TYPE.keys.find { |k| defined_variables.include?(k) }
      return KEY_TO_TYPE[key] if key

      nil
    end

    # Detects interface type according to sysconfig's INTERFACETYPE option
    #
    # This option is kind of special that it deserve own method mostly for documenting
    # that it should almost never be used. Only meaningful cases for its usage is
    # dummy device definition and loopback device (when an additional to standard ifcfg-lo
    # is defined)
    #
    # @return [Y2Network::InterfaceType, nil] type according to INTERFACETYPE option
    #                                    value if recognized, nil otherwise
    def type_from_interfacetype
      return Y2Network::InterfaceType.from_short_name(interfacetype) if interfacetype

      nil
    end

    # Distinguishes interface type by its name
    #
    # The only case should be loopback device with special name (in sysconfig) "lo"
    #
    # @return [Y2Network::InterfaceType, nil] InterfaceType::LO or nil if not loopback
    def type_by_name
      Y2Network::InterfaceType::LO if interface == "lo"
      nil
    end

    # Returns a list of those keys that have a value
    #
    # @return [Array<String>] name of keys that are included in the file
    def defined_variables
      return @defined_variables if @defined_variables

      if exist?
        @defined_variables = Yast::SCR.Dir(Yast::Path.new(".network.value.\"#{interface}\""))
      end
      @defined_variables ||= []
    end

    # Fetches the value for a given key
    #
    # @param key [String] Value key
    # @param type [Symbol] Type to convert the value to
    # @return [Object] Value for the given key
    def fetch_scalar(key, type)
      path = Yast::Path.new(".network.value.\"#{interface}\".#{key}")
      value = Yast::SCR.Read(path)&.strip
      send("value_as_#{type}", value)
    end

    # Returns a hash containing all the values for a given key
    #
    # When working with collections, all values are represented in a hash, indexed by the suffix.
    #
    # For instance, this set of IPADDR_* keys:
    #
    #   IPADDR='192.168.122.1'
    #   IPADDR0='192.168.122.2'
    #
    # will be represented like:
    #
    #  { :default => "192.168.122.1", "0" => "192.168.122.2" }
    #
    # @param key [Symbol] Key base name (without the suffix)
    # @param type [Symbol] Type to convert the values to
    # @return [Hash<String, Object>]
    def fetch_collection(key, type)
      collection_keys(key).each_with_object({}) do |k, h|
        index = k.sub(key, "")
        h[index] = fetch_scalar(k, type)
      end
    end

    def collection_keys(key)
      collection_keys = defined_variables.select do |k|
        k == key || k.start_with?(key)
      end
      other_keys = self.class.variables.keys - [key]
      collection_keys - other_keys
    end

    # Converts the value into a string (or nil if empty)
    #
    # @param [String] value
    # @return [String,nil]
    def value_as_string(value)
      (value.nil? || value.empty?) ? nil : value
    end

    # Converts the value into an integer (or nil if empty)
    #
    # @param [String] value
    # @return [Integer,nil]
    def value_as_integer(value)
      (value.nil? || value.empty?) ? nil : value.to_i
    end

    # Converts the value into an float (or nil if empty)
    #
    # @param [String] value
    # @return [Float,nil]
    def value_as_float(value)
      (value.nil? || value.empty?) ? nil : value.to_f
    end

    # Converts the value into a symbol (or nil if empty)
    #
    # @param [String] value
    # @return [Symbol,nil]
    def value_as_symbol(value)
      (value.nil? || value.empty?) ? nil : value.downcase.to_sym
    end

    # Converts the value into a IPAddress (or nil if empty)
    #
    # @param [String] value
    # @return [Y2Network::IPAddress,nil]
    def value_as_ipaddr(value)
      (value.nil? || value.empty?) ? nil : Y2Network::IPAddress.from_string(value)
    end

    # Writes an array as a value for a given key
    #
    # @param key    [String] Key
    # @param values [Array<#to_s>] Values to write
    # @see #clean_collection
    def write_collection(key, values)
      clean_collection(key)
      values.each do |suffix, value|
        write_key = (suffix == :default) ? key : "#{key}#{suffix}"
        write_scalar(write_key, value)
      end
    end

    # Cleans all values from a collection
    #
    # @todo There is no way to remove elements from the configuration file so we are setting them
    #   to blank. However, using CFA might be an alternative.
    #
    # @param key [String] Key
    def clean_collection(key)
      collection_keys(key).each { |k| write_scalar(k, nil) }
    end

    # Writes the value for a given key
    #
    # If the value is set to nil, the key will be removed.
    #
    # @param key   [Symbol] Key
    # @param value [#to_s,nil] Value to write
    def write_scalar(key, value)
      raw_value = value ? value.to_s : nil
      path = Yast::Path.new(".network.value.\"#{interface}\".#{key}")
      Yast::SCR.Write(path, raw_value)
    end

    # Returns the variables which are collections
    #
    # @return [Array<Variable>] List of collection variables
    def collection_variables
      self.class.variables.values.select(&:collection?)
    end
  end
end
