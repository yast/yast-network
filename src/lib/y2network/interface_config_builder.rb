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
      log.info "Specialized builder for #{type} not found. Falling back to default. #{e.inspect}"
      new(type: type, config: config)
    end

    # @return [String] Device name (eth0, wlan0, etc.)
    attr_accessor :name
    # @return [Y2Network::InterfaceType] type of @see Y2Network::Interface which is intended to be build
    attr_accessor :type
    # @return [Y2Network::ConnectionConfig] connection config on which builder operates
    attr_reader :connection_config
    # @return [Symbol,nil] Mechanism to rename the interface (no hardware based, :mac or :bus_id)
    attr_writer :renaming_mechanism

    # Constructor
    #
    # Load with reasonable defaults
    # @param type [Y2Network::InterfaceType] type of device
    # @param config [Y2Network::ConnectionConfig::Base, nil] existing configuration of device or nil
    #   for newly created
    def initialize(type:, config: nil)
      @type = type
      # TODO: also config need to store it, as newly added can be later
      # edited with option for not yet created interface
      @newly_added = config.nil?
      if !config
        config = connection_config_klass(type).new
        config.propose
      end
      @connection_config = config
    end

    def newly_added?
      @newly_added
    end

    # saves builder content to backend
    # @ TODO now still LanItems actively query config attribute and write it
    #   down, so here mainly workarounds, but ideally this save should change
    #   completely backend
    def save
      if !driver.empty?
        # TODO: new backend?
        Yast::LanItems.setDriver(driver)
        Yast::LanItems.driver_options[driver] = driver_options
      end

      @connection_config.name = name
      @connection_config.interface = name
      yast_config.connections.add_or_update(@connection_config)
      yast_config.rename_interface(@old_name, name, renaming_mechanism) if renamed_interface?

      # create new instance as name can change
      firewall_interface = Y2Firewall::Firewalld::Interface.new(name)
      if Y2Firewall::Firewalld.instance.installed?
        # TODO: New backend?
        Yast::LanItems.firewall_zone = firewall_zone
        # TODO: should change only if different, but maybe firewall_interface responsibility?
        firewall_interface.zone = firewall_zone if !firewall_interface.zone || firewall_zone != firewall_interface.zone.name
      end

      nil
    end

    # Determines whether the interface has been renamed
    #
    # @return [Boolean] true if it was renamed; false otherwise
    def renamed_interface?
      return false unless interface
      name != interface.name || @renaming_mechanism != interface.renaming_mechanism
    end

    # Renames the interface
    #
    # @param new_name [String] New interface's name
    def rename_interface(new_name)
      @old_name ||= name
      self.name = new_name
    end

    # Returns the current renaming mechanism
    #
    # @return [Symbol,nil] Mechanism to rename the interface (nil -no rename-, :mac or :bus_id)
    def renaming_mechanism
      @renaming_mechanism || interface.renaming_mechanism
    end

    # Returns the underlying interface
    #
    # If the interface has been renamed, take the old name into account.
    #
    # @return [Y2Network::Interface,nil]
    def interface
      @interface ||= yast_config.interfaces.by_name(@old_name || name)
    end

    # how many device names is proposed
    NEW_DEVICES_COUNT = 10
    # Proposes bunch of possible names for interface
    # do not modify anything
    # @return [Array<String>]
    def proposed_names
      # TODO: new backend?
      Yast::LanItems.new_type_devices(type.short_name, NEW_DEVICES_COUNT)
    end

    # checks if passed name is valid as interface name
    # TODO: looks sysconfig specific
    def valid_name?(name)
      !!(name =~ /^[[:alnum:]._:-]{1,15}\z/)
    end

    # checks if interface name already exists
    def name_exists?(name)
      # TODO: new backend
      Yast::NetworkInterfaces.List("").include?(name)
    end

    # gets valid characters that can be used in interface name
    # TODO: looks sysconfig specific
    def name_valid_characters
      Yast::NetworkInterfaces.ValidCharsIfcfg
    end

    # gets a list of available kernel modules for the interface
    def kernel_modules
      # TODO: new backend?
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
      @connection_config.bootproto
    end

    # @param[String, Y2Network::BootProtocol]
    def boot_protocol=(value)
      value = value.name if value.is_a?(Y2Network::BootProtocol)
      @connection_config.bootproto = Y2Network::BootProtocol.from_name(value)
    end

    # @return [Startmode]
    def startmode
      @connection_config.startmode
    end

    # @param [String,Y2Network::Startmode] name startmode name used to create Startmode object
    #   or object itself
    def startmode=(name)
      mode = name.is_a?(Startmode) ? name : Startmode.create(name)
      # assign only if it is not already this value. This helps with ordering of ifplugd_priority
      return if @connection_config.startmode && @connection_config.startmode.name == mode.name

      @connection_config.startmode = mode
    end

    # @param [Integer] value priority value
    def ifplugd_priority=(value)
      if !@connection_config.startmode || @connection_config.startmode.name != "ifplugd"
        @connection_config.startmode = Startmode.create("ifplugd")
      end
      @connection_config.startmode.priority = value.to_i
    end

    # @return [Integer]
    def ifplugd_priority
      startmode.name == "ifplugd" ? startmode.priority : 0
    end

    # gets currently assigned kernel module
    def driver
      # TODO: new backend
      @driver ||= Yast::Ops.get_string(Yast::LanItems.getCurrentItem, ["udev", "driver"], "")
    end

    # sets kernel module for interface
    def driver=(value)
      # TODO: new backend
      @driver = value
    end

    # gets specific options for kernel driver
    def driver_options
      target_driver = @driver
      target_driver = hwinfo.module if target_driver.empty?
      # TODO: new backend
      @driver_options ||= Yast::LanItems.driver_options[target_driver] || ""
    end

    # sets specific options for kernel driver
    def driver_options=(value)
      # TODO: new backend
      @driver_options = value
    end

    # gets aliases for interface
    # @return [Array<Hash>] hash values are `:label` for alias label,
    #   `:ip` for ip address, `:mask` for netmask and `:prefixlen` for prefix.
    #   Only one of `:mask` and `:prefixlen` is set.
    def aliases
      return @aliases if @aliases

      aliases = @connection_config.ip_aliases.map do |data|
        {
          label:     data.label.to_s,
          ip:        data.address.address.to_s,
          prefixlen: data.address.prefix.to_s,
          # NOTE: new API does not have netmask at all, we need to adapt UI to clearly mention only prefix
        }
      end
      @aliases = aliases
    end

    # sets aliases for interface
    # @param value [Array<Hash>] see #aliases for hash values
    def aliases=(value)
      @aliases = value
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
      default = @connection_config.ip
      if default
        default.address.address.to_s
      else
        ""
      end
    end

    # @param [String] value
    def ip_address=(value)
      if value.nil? || value.empty?
        @connection_config.ip = nil
      else
        ip_config_default.address.address = value
      end
    end

    # @return [String] returns prefix or netmask. prefix in format "/<prefix>"
    def subnet_prefix
      if @connection_config.ip
        "/" + @connection_config.ip.address.prefix.to_s
      else
        ""
      end
    end

    # @param [String] value prefix or netmask is accepted. prefix in format "/<prefix>"
    def subnet_prefix=(value)
      if value.empty?
        ip_config_default.address.prefix = nil
      elsif value.start_with?("/")
        ip_config_default.address.prefix = value[1..-1].to_i
      elsif value.size < 3 # one or two digits can be only prefixlen
        ip_config_default.address.prefix = value.to_i
      elsif value =~ /^\d{3}$/
        ip_config_default.address.prefix = value.to_i
      else
        ip_config_default.address.netmask = value
      end
    end

    # @return [String]
    def hostname
      # TODO: write it
      ""
    end

    # @param [String] value
    def hostname=(value)
      # TODO: write it
    end

    # sets remote ip for ptp connections
    # @return [String]
    def remote_ip
      default = @connection_config.ip
      if default
        default.remote_address.to_s
      else
        ""
      end
    end

    # @param [String] value
    def remote_ip=(value)
      ip_config_default.remote_address = IPAddress.from_string(value)
    end

    # Gets Maximum Transition Unit
    # @return [String]
    def mtu
      @connection_config.mtu.to_s
    end

    # Sets Maximum Transition Unit
    # @param [String] value
    def mtu=(value)
      @connection_config.mtu = value.to_i
    end

  private

    def hwinfo
      @hwinfo ||= Hwinfo.new(name: name)
    end

    def ip_config_default
      return @connection_config.ip if @connection_config.ip
      @connection_config.ip = ConnectionConfig::IPConfig.new(IPAddress.new("0.0.0.0"))
    end

    # Returns the connection config class for a given type
    #
    # @param type [Y2Network::InterfaceType] type of device
    def connection_config_klass(type)
      ConnectionConfig.const_get(type.class_name)
    rescue NameError
      log.error "Could not find a class to handle '#{type.name}' connections"
      ConnectionConfig::Base
    end

    # Saves aliases to current connection config object
    def save_aliases_to_connection
      @connection_config.ip_aliases.clear
      aliases.each_with_index do |h, i|
        ip_addr = IPAddress.from_string(h[:ip])
        if h[:prefixlen] && !h[:prefixlen].empty?
          ip_addr.prefix = h[:prefixlen].delete("/").to_i
        elsif h[:mask] && !h[:mask].empty?
          ip_addr.netmask = h[:mask]
        end
        @connection_config.ip_aliases << ConnectionConfig::IPConfig.new(
          ip_addr,
          label: h[:label],
          id:    "_#{i}" # TODO: remember original prefixes
        )
      end
    end

    # Helper method to access to the current configuration
    #
    # @return [Y2Network::Config]
    def yast_config
      Yast::Lan.yast_config
    end
  end
end
