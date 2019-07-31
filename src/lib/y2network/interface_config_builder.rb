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

require "y2network/connection_config"
require "y2network/hwinfo"
require "y2network/startmode"
require "y2network/boot_protocol"
require "y2network/ip_address"
require "y2firewall/firewalld"
require "y2firewall/firewalld/interface"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"
Yast.import "Netmask"

module Y2Network
  # Collects data from the UI until we have enough of it to create a
  # {Y2Network::ConnectionConfig::Base} object.
  #
  # {Yast::LanItemsClass#Commit Yast::LanItems.Commit(builder)} use it.
  class InterfaceConfigBuilder
    include Yast::Logger

    # Load fresh instance of interface config builder for given type.
    # It can be specialized type or generic, depending if specialized is needed.
    # @param type [Y2Network::InterfaceType,String] type of device or its short name
    # @param config [Y2Network::ConnectionConfig::Base, nil] existing configuration of device or nil
    #   for newly created
    def self.for(type, config: nil)
      if !type.is_a?(InterfaceType)
        type = InterfaceType.from_short_name(type) or raise "Unknown type #{type.inspect}"
      end
      require "y2network/interface_config_builders/#{type.file_name}"
      InterfaceConfigBuilders.const_get(type.class_name).new(config: config)
    rescue LoadError => e
      log.info "Specialed builder for #{type} not found. Fallbacking to default. #{e.inspect}"
      new(type: type, config: config)
    end

    # @return [String] Device name (eth0, wlan0, etc.)
    attr_accessor :name
    # @return [Y2Network::InterfaceType] type of @see Y2Network::Interface which is intended to be build
    attr_accessor :type

    # Constructor
    #
    # Load with reasonable defaults
    # @param type [Y2Network::InterfaceType] type of device
    # @param config [Y2Network::ConnectionConfig::Base, nil] existing configuration of device or nil
    #   for newly created
    def initialize(type:, config: nil)
      @type = type
      @config = init_device_config({})
      @s390_config = init_device_s390_config({})
      # TODO: also config need to store it, as newly added can be later
      # edited with option for not yet created interface
      @newly_added = config.nil?
      # TODO: create specialized connection for type
      @connection_config = config || connection_config_klass(type).new
    end

    def newly_added?
      Yast::LanItems.operation == :add
    end

    # saves builder content to backend
    # @ TODO now still LanItems actively query config attribute and write it
    #   down, so here mainly workarounds, but ideally this save should change
    #   completely backend
    def save
      Yast::LanItems.Items[Yast::LanItems.current]["ifcfg"] = name
      if !driver.empty?
        Yast::LanItems.setDriver(driver)
        Yast::LanItems.driver_options[driver] = driver_options
      end

      @connection_config.interface = name
      Yast::Lan.yast_config.connections.add_or_update(@connection_config)

      # create new instance as name can change
      firewall_interface = Y2Firewall::Firewalld::Interface.new(name)
      if Y2Firewall::Firewalld.instance.installed?
        Yast::LanItems.firewall_zone = firewall_zone
        # TODO: should change only if different, but maybe firewall_interface responsibility?
        firewall_interface.zone = firewall_zone if !firewall_interface.zone || firewall_zone != firewall_interface.zone.name
      end

      save_aliases

      nil
    end

    # how many device names is proposed
    NEW_DEVICES_COUNT = 10
    # Proposes bunch of possible names for interface
    # do not modify anything
    # @return [Array<String>]
    def proposed_names
      Yast::LanItems.new_type_devices(type.short_name, NEW_DEVICES_COUNT)
    end

    # checks if passed name is valid as interface name
    # TODO: looks sysconfig specific
    def valid_name?(name)
      !!(name =~ /^[[:alnum:]._:-]{1,15}\z/)
    end

    # checks if interface name already exists
    def name_exists?(name)
      Yast::NetworkInterfaces.List("").include?(name)
    end

    # gets valid characters that can be used in interface name
    # TODO: looks sysconfig specific
    def name_valid_characters
      Yast::NetworkInterfaces.ValidCharsIfcfg
    end

    # gets a list of available kernel modules for the interface
    def kernel_modules
      Yast::LanItems.GetItemModules("")
    end

    # gets currently assigned firewall zone
    def firewall_zone
      return @firewall_zone if @firewall_zone

      # TODO: handle renaming
      firewall_interface = Y2Firewall::Firewalld::Interface.new(name)
      @firewall_zone = firewall_interface.zone && firewall_interface.zone.name
    end

    # sets assigned firewall zone
    def firewall_zone=(value)
      @firewall_zone = value
    end

    # @return [Y2Network::BootProtocol]
    def boot_protocol
      select_backend(
        Y2Network::BootProtocol.from_name(@config["BOOTPROTO"]),
        @connection_config.bootproto
      )
    end

    # @param[String, Y2Network::BootProtocol]
    def boot_protocol=(value)
      value = value.name if value.is_a?(Y2Network::BootProtocol)
      @config["BOOTPROTO"] = value
      @connection_config.bootproto = Y2Network::BootProtocol.from_name(value)
    end

    # @return [Startmode]
    def startmode
      # in future use only @connection_config and just delegate method
      startmode = Startmode.create(@config["STARTMODE"])
      return nil unless startmode

      startmode.priority = @config["IFPLUGD_PRIORITY"] if startmode.name == "ifplugd"
      select_backend(
        startmode,
        @connection_config.startmode
      )
    end

    # @param [String,Y2Network::Startmode] name startmode name used to create Startmode object
    #   or object itself
    def startmode=(name)
      mode = name.is_a?(Startmode) ? name : Startmode.create(name)
      if !mode # invalid startmode e.g. in CLI
        @config["STARTMODE"] = ""
        return
      end

      # assign only if it is not already this value. This helps with ordering of ifplugd_priority
      if !@connection_config.startmode || @connection_config.startmode.name != mode.name
        @connection_config.startmode = mode
      end
      @config["STARTMODE"] = mode.name
    end

    # @param [Integer] value priority value
    def ifplugd_priority=(value)
      @config["IFPLUGD_PRIORITY"] = value.to_s
      if !@connection_config.startmode || @connection_config.startmode.name != "ifplugd"
        @connection_config.startmode = Startmode.create("ifplugd")
      end
      @connection_config.startmode.priority = value.to_i
    end

    # @return [Integer]
    def ifplugd_priority
      # in future use only @connection_config and just delegate method
      startmode = @connection_config.startmode
      select_backend(
        @config["IFPLUGD_PRIORITY"].to_i,
        startmode.name == "ifplugd" ? startmode.priority : 0
      )
    end

    # gets currently assigned kernel module
    def driver
      @driver ||= Yast::Ops.get_string(Yast::LanItems.getCurrentItem, ["udev", "driver"], "")
    end

    # sets kernel module for interface
    def driver=(value)
      @driver = value
    end

    # gets specific options for kernel driver
    def driver_options
      target_driver = @driver
      target_driver = hwinfo.module if target_driver.empty?
      @driver_options ||= Yast::LanItems.driver_options[target_driver] || ""
    end

    # sets specific options for kernel driver
    def driver_options=(value)
      @driver_options = value
    end

    # gets aliases for interface
    # @return [Array<Hash>] hash values are `:label` for alias label,
    #   `:ip` for ip address, `:mask` for netmask and `:prefixlen` for prefix.
    #   Only one of `:mask` and `:prefixlen` is set.
    def aliases
      return @aliases if @aliases

      old_aliases = Yast::LanItems.aliases.each_value.map do |data|
        {
          label:     data["LABEL"] || "",
          ip:        data["IPADDR"] || "",
          mask:      data["NETMASK"] || "",
          prefixlen: data["PREFIXLEN"] || ""
        }
      end

      new_aliases = @connection_config.ip_configs.select { |c| c.id != "" }.map do |data|
        {
          label:     data.label,
          ip:        data.address.address,
          prefixlen: data.address.prefix
          # NOTE: new API does not have netmask at all, we need to adapt UI to clearly mention only prefix
        }
      end
      select_backend(old_aliases, new_aliases)
    end

    # sets aliases for interface
    # @param value [Array<Hash>] see #aliases for hash values
    def aliases=(value)
      @aliases = value

      # connection config
      # keep only default as aliases does not handle default ip config
      @connection_config.ip_configs.delete_if { |c| c.id != "" }
      value.each_with_index do |h, i|
        ip_addr = IPAddress.from_string(h[:ip])
        if h[:prefixlen] && !h[:prefixlen].empty?
          ip_addr.prefix = h[:prefixlen].delete("/").to_i
        elsif h[:mask] && !h[:mask].empty?
          ip.netmask = h[:mask]
        end
        @connection_config.ip_configs << ConnectionConfig::IPConfig.new(
          ip_addr,
          label: h[:label],
          id:    "_#{i}" # TODO: remember original prefixes
        )
      end
    end

    # gets interface name that will be assigned by udev
    def udev_name
      # cannot cache as EditNicName dialog can change it
      Yast::LanItems.current_udev_name
    end

    # TODO: eth only?
    # @return [String]
    def ethtool_options
      @config["ETHTOOL_OPTIONS"]
    end

    # @param [String] value
    def ethtool_options=(value)
      @config["ETHTOOL_OPTIONS"] = value
    end

    # @return [String]
    def ip_address
      old = @config["IPADDR"]

      # FIXME: workaround to remove when primary ip config is separated from the rest
      default = (@connection_config.ip_configs || []).find { |c| c.id == "" }
      new_ = if default
        default.address.address
      else
        ""
      end
      select_backend(old, new_)
    end

    # @param [String] value
    def ip_address=(value)
      @config["IPADDR"] = value

      # connection_config
      if value.nil? || value.empty?
        # in such case remove default config
        @connection_config.ip_configs.delete_if { |c| c.id == "" }
      else
        ip_config_default.address.address = value
      end
    end

    # @return [String] returns prefix or netmask. prefix in format "/<prefix>"
    def subnet_prefix
      old = if @config["PREFIXLEN"] && !@config["PREFIXLEN"].empty?
        "/#{@config["PREFIXLEN"]}"
      else
        @config["NETMASK"] || ""
      end
      default = (@connection_config.ip_configs || []).find { |c| c.id == "" }
      new_ = if default
        "/" + default.address.prefix.to_s
      else
        ""
      end
      select_backend(old, new_)
    end

    # @param [String] value prefix or netmask is accepted. prefix in format "/<prefix>"
    def subnet_prefix=(value)
      if value.empty?
        @config["PREFIXLEN"] = ""
        @config["NETMASK"] = ""
        ip_config_default.address.prefix = nil
      elsif value.start_with?("/")
        @config["PREFIXLEN"] = value[1..-1]
        ip_config_default.address.prefix = value[1..-1].to_i
      elsif value.size < 3 # one or two digits can be only prefixlen
        @config["PREFIXLEN"] = value
        ip_config_default.address.prefix = value.to_i
      else
        param = Yast::Netmask.Check6(value) ? "PREFIXLEN" : "NETMASK"
        @config[param] = value
        if param == "PREFIXLEN"
          ip_config_default.address.prefix = value.to_i
        else
          ip_config_default.address.netmask = value
        end
      end
    end

    # @return [String]
    def hostname
      @config["HOSTNAME"]
    end

    # @param [String] value
    def hostname=(value)
      @config["HOSTNAME"] = value
    end

    # sets remote ip for ptp connections
    # @return [String]
    def remote_ip
      old = @config["REMOTEIP"]
      default = @connection_config.ip_configs.find { |c| c.id == "" }
      new_ = if default
        default.remote_address.to_s
      else
        ""
      end

      select_backend(old, new_)
    end

    # @param [String] value
    def remote_ip=(value)
      @config["REMOTEIP"] = value
      ip_config_default.remote_address = IPAddress.from_string(value)
    end

    # Gets Maximum Transition Unit
    # @return [String]
    def mtu
      select_backend(
        @config["MTU"],
        @connection_config.mtu.to_s
      )
    end

    # Sets Maximum Transition Unit
    # @param [String] value
    def mtu=(value)
      @config["MTU"] = value

      @connection_config.mtu = value.to_i
    end

    # @return [Array(2)<String,String>] user and group of tunnel
    def tunnel_user_group
      [@config["TUNNEL_SET_OWNER"], @config["TUNNEL_SET_GROUP"]]
    end

    def assign_tunnel_user_group(user, group)
      @config["TUNNEL_SET_OWNER"] = user
      @config["TUNNEL_SET_GROUP"] = group
    end

    # Provides stored configuration in sysconfig format
    #
    # @return [Hash<String, String>] where key is sysconfig option and value is the option's value
    def device_sysconfig
      # initalize options which has to be known and was not set by the user explicitly
      init_mandatory_options

      # with naive implementation of filtering options by type
      config = @config.dup

      # filter out options which are not needed
      config.delete_if { |k, _| k =~ /WIRELESS.*/ } if type != InterfaceType::WIRELESS
      config.delete_if { |k, _| k =~ /BONDING.*/ } if type != InterfaceType::BONDING
      config.delete_if { |k, _| k =~ /BRIDGE.*/ } if type != InterfaceType::BRIDGE
      if ![InterfaceType::TUN, InterfaceType::TAP].include?(type)
        config.delete_if { |k, _| k =~ /TUNNEL.*/ }
      end
      config.delete_if { |k, _| k == "VLAN_ID" || k == "ETHERDEVICE" } if type != InterfaceType::VLAN
      config.delete_if { |k, _| k == "IPOIB_MODE" } if type != InterfaceType::INFINIBAND
      config.delete_if { |k, _| k == "INTERFACE" } if type != InterfaceType::DUMMY
      config.delete_if { |k, _| k == "IFPLUGD_PRIORITY" } if config["STARTMODE"] != "ifplugd"

      config.merge("_aliases" => lan_items_format_aliases)
    end

    # Updates itself according to the given sysconfig configuration
    #
    # @param devmap [Hash<String, String>, nil] a key, value map where key is sysconfig option
    #                                           and corresponding value is the option value
    def load_sysconfig(devmap)
      @config.merge!(devmap || {})
    end

    def load_s390_config(devmap)
      @s390_config.merge!(devmap || {})
    end

  private

    # Initializes device configuration map with default values when needed
    #
    # @param devmap [Hash<String, String>] current device configuration
    #
    # @return device configuration map where unspecified values were set
    #                to reasonable defaults
    def init_device_config(devmap)
      # the defaults here are what sysconfig defaults to
      # (as opposed to what a new interface gets, in {#Select)}
      defaults = YAML.load_file(Yast::Directory.find_data_file("network/sysconfig_defaults.yml"))
      defaults.merge(devmap)
    end

    def init_device_s390_config(devmap)
      Yast.import "Arch"

      return {} if !Yast::Arch.s390

      # Default values used when creating an emulated NIC for physical s390 hardware.
      s390_defaults = YAML.load_file(Yast::Directory.find_data_file("network/s390_defaults.yml"))
      s390_defaults.merge(devmap)
    end

    # returns a map with device options for newly created item
    def init_mandatory_options
      # FIXME: NetHwDetection is done in Lan.Read
      Yast.import "NetHwDetection"

      # #104494 - always write IPADDR+NETMASK, even empty
      # #50955 omit computable fields
      @config["BROADCAST"] = ""
      @config["NETWORK"] = ""

      if !@config["NETMASK"] || @config["NETMASK"].empty?
        @config["NETMASK"] = Yast::NetHwDetection.result["NETMASK"] || "255.255.255.0"
      end

      @config["STARTMODE"] = new_device_startmode if !@config["STARTMODE"] || @config["STARTMODE"].empty?
    end

    # returns default startmode for a new device
    #
    # startmode is returned according product, Arch and current device type
    def new_device_startmode
      Yast.import "ProductFeatures"

      product_startmode = Yast::ProductFeatures.GetStringFeature(
        "network",
        "startmode"
      )

      startmode = case product_startmode
      when "ifplugd"
        if replace_ifplugd?
          hotplug_interface? ? "hotplug" : "auto"
        else
          product_startmode
        end
      when "auto"
        "auto"
      else
        hotplug_interface? ? "hotplug" : "auto"
      end

      startmode
    end

    def replace_ifplugd?
      Yast.import "Arch"
      Yast.import "NetworkService"

      return true if !Yast::Arch.is_laptop
      return true if Yast::NetworkService.is_network_manager
      # virtual devices cannot expect any event from ifplugd
      return true if ["bond", "vlan", "br"].include? type.short_name

      false
    end

    def hotplug_interface?
      hwinfo.hotplug
    end

    def hwinfo
      @hwinfo ||= Hwinfo.new(name: name)
    end

    def lan_items_format_aliases
      aliases.each_with_index.each_with_object({}) do |(a, i), res|
        res[i] = {
          "IPADDR"    => a[:ip],
          "LABEL"     => a[:label],
          "PREFIXLEN" => a[:prefixlen],
          "NETMASK"   => a[:mask]

        }
      end
    end

    def save_aliases
      log.info "setting new aliases #{lan_items_format_aliases.inspect}"
      aliases_to_delete = Yast::LanItems.aliases.dup # #48191
      Yast::NetworkInterfaces.Current["_aliases"] = lan_items_format_aliases
      Yast::LanItems.aliases = lan_items_format_aliases
      aliases_to_delete.each_pair do |a, v|
        Yast::NetworkInterfaces.DeleteAlias(Yast::NetworkInterfaces.Name, a) if v
      end
    end

    def ip_config_default
      default = @connection_config.ip_configs.find { |c| c.id == "" }
      if !default
        default = ConnectionConfig::IPConfig.new(IPAddress.new("0.0.0.0")) # fake ip as it will be replaced soon
        @connection_config.ip_configs << default
      end
      default
    end

    # method that allows easy change of backend for providing data
    # it also logs error if result differs
    # TODO: Only temporary method for testing switch of backends. Remove it from production
    def select_backend(old, new)
      log.error "Different value in backends. Old: #{old.inspect} New: #{new.inspect}" if new != old

      old
    end

    # Returns the connection config class for a given type
    #
    # @param type [Y2Network::InterfaceType] type of device
    def connection_config_klass(type)
      ConnectionConfig.const_get(type.name)
    rescue NameError
      log.error "Could not find a class to handle '#{type.name}' connections"
      ConnectionConfig::Base
    end
  end
end
