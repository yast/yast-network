# ***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# **************************************************************************
require "yast"
require "yaml"
require "y2storage"
require "network/network_autoyast"
require "network/install_inf_convertor"
require "network/wicked"
require "y2network/config"
require "y2network/boot_protocol"

require "shellwords"

module Yast
  # FIXME: well this class really is not nice
  class LanItemsClass < Module
    include Logger
    include Wicked

    def main
      textdomain "network"

      Yast.import "Arch"
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkConfig"
      Yast.import "Directory"
      Yast.include self, "network/complex.rb"
      Yast.include self, "network/routines.rb"
      Yast.include self, "network/lan/s390.rb"

      reset_cache

      # Hardware information
      # @see #ReadHardware
      @Hardware = []
      @udev_net_rules = {}
      @driver_options = {}

      # used at autoinstallation time
      @autoinstall_settings = {}

      # Data was modified?
      # current selected HW
      @hw = {}

      # Which operation is pending?
      @operation = nil

      @description = ""

      @type = ""
      # ifcfg name for the @current device
      @device = ""
      @current = -1
      @hotplug = ""

      @Requires = []

      # s390 options
      @qeth_portnumber = ""
      # * ctc as PROTOCOL (or ctc mode, number in { 0, 1, .., 4 }, default: 0)
      @chan_mode = "0"
      @qeth_options = ""
      @ipa_takeover = false
      # * iucv as ROUTER (or iucv user, a zVM guest, string of 1 to 8 chars )
      @iucv_user = ""
      # #84148
      # 26bdd00.pdf
      # Ch 7: qeth device driver for OSA-Express (QDIO) and HiperSockets
      # MAC address handling for IPv4 with the layer2 option
      @qeth_layer2 = false
      @qeth_macaddress = "00:00:00:00:00:00"
      @qeth_chanids = ""
      # Timeout for LCS LANCMD
      @lcs_timeout = "5"

      # aliases
      @aliases = {}

      # for TUN / TAP devices
      @tunnel_set_owner = ""
      @tunnel_set_group = ""

      # this is the map of kernel modules vs. requested firmware
      # non-empty keys are firmware packages shipped by SUSE
      @request_firmware = YAML.load_file(Directory.find_data_file("network/firmwares.yml"))
    end

    # Returns configuration of item (see LanItems::Items) with given id.
    #
    # @param itemId [Integer] a key for {#Items}
    def GetLanItem(itemId)
      Items()[itemId] || {}
    end

    # Returns configuration for currently modified item.
    def getCurrentItem
      GetLanItem(@current)
    end

    # Returns true if the item (see LanItems::Items) has
    # netconfig configuration.
    #
    # @param itemId [Integer] a key for {#Items}
    def IsItemConfigured(itemId)
      ret = !GetLanItem(itemId)["ifcfg"].to_s.empty?
      log.info("IsItemConfigured: item=#{itemId} configured=#{ret}")

      ret
    end

    # Returns device name for given lan item.
    #
    # First it looks into the item's netconfig and if it doesn't exist
    # it uses device name from hwinfo if available.
    #
    # @param item_id [Integer] a key for {#Items}
    def GetDeviceName(item_id)
      lan_item = GetLanItem(item_id)

      return lan_item["ifcfg"] if lan_item["ifcfg"]
      return lan_item["hwinfo"]["dev_name"] || "" if lan_item["hwinfo"]

      log.error("Item #{item_id} has no dev_name nor configuration associated")
      "" # this should never happen
    end

    # transforms given list of item ids onto device names
    #
    # item id is index into internal @Items structure
    def GetDeviceNames(items)
      return [] unless items

      items.map { |itemId| GetDeviceName(itemId) }.reject(&:empty?)
    end

    # Return the actual name of the current {LanItems}
    #
    # @return [String] the actual name for the current device
    def current_name
      current_name_for(@current)
    end

    # Returns device type for particular lan item
    #
    # @param itemId [Integer] a key for {#Items}
    def GetDeviceType(itemId)
      NetworkInterfaces.GetType(GetDeviceName(itemId))
    end

    # Returns ifcfg configuration for particular item
    #
    # @param itemId [Integer] a key for {#Items}
    def GetDeviceMap(itemId)
      return nil if !IsItemConfigured(itemId)

      NetworkInterfaces.devmap(GetDeviceName(itemId))
    end

    # Function which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Creates list of all known netcard items
    #
    # It means list of item ids of all netcards which are detected and/or
    # configured in the system
    def GetNetcardInterfaces
      Items().keys
    end

    # Finds all NICs configured with DHCP
    #
    # @return [Array<String>] list of NIC names which are configured to use (any) dhcp
    def find_dhcp_ifaces
      find_by_sysconfig { |ifcfg| dhcp?(ifcfg) }
    end

    # Finds all devices which has DHCLIENT_SET_HOSTNAME set to "yes"
    #
    # @return [Array<String>] list of NIC names which has the option set to "yes"
    def find_set_hostname_ifaces
      find_by_sysconfig do |ifcfg|
        ifcfg["DHCLIENT_SET_HOSTNAME"] == "yes"
      end
    end

    # Creates a list of config files which contain corrupted DHCLIENT_SET_HOSTNAME setup
    #
    # @return [Array] list of config file names
    def invalid_dhcp_cfgs
      devs = LanItems.find_set_hostname_ifaces
      dev_ifcfgs = devs.map { |d| "ifcfg-#{d}" }

      return dev_ifcfgs if devs.size > 1
      return dev_ifcfgs << "dhcp" if !devs.empty? && DNS.dhcp_hostname

      []
    end

    # Checks if system DHCLIENT_SET_HOSTNAME is valid
    #
    # @return [Boolean]
    def valid_dhcp_cfg?
      invalid_dhcp_cfgs.empty?
    end

    # Clears internal cache of the module to default values
    #
    # TODO: LanItems consists of several sets of internal variables.
    # 1) cache of items describing network interface
    # 2) variables used as a kind of iterator in the cache
    # 3) variables which keeps (some of) attributes of the current item (= item
    # which is being pointed by the iterator)
    def reset_cache
      LanItems.Items = {}

      @modified = false
    end

    # Imports data from AY profile
    #
    # As network related configuration is spread over the whole AY profile's
    # networking section the function requires hash map with whole AY profile hash
    # representation as returned by LanAutoClient#FromAY profile.
    #
    # @param settings [Hash] AY profile converted into hash
    # @return [Boolean] on success
    def Import(settings)
      reset_cache
      # settings == {} has special meaning 'Reset' used by AY
      SetModified() if !settings.empty?

      true
    end

    # Checks whether given device configuration is set to use a dhcp bootproto
    #
    # ideally should replace @see isCurrentDHCP
    def dhcp?(devmap)
      return false unless devmap["BOOTPROTO"]

      Y2Network::BootProtocol.from_name(devmap["BOOTPROTO"]).dhcp?
    end

    #-------------------
    # PRIVATE FUNCTIONS

    # Commit pending operation
    #
    # It commits *only* content of the corresponding ifcfg into NetworkInterfaces.
    # All other stuff which is managed by LanItems (like udev's, ...) is handled
    # elsewhere
    #
    # @return true if success
    def Commit(builder)
      log.info "committing builder #{builder.inspect}"
      builder.save # does all modification, later only things that is not yet converted

      # TODO: still needed?
      if DriverType(builder.type.short_name) == "ctc"
        if Ops.get(NetworkConfig.Config, "WAIT_FOR_INTERFACES").nil? ||
            Ops.less_than(
              Ops.get_integer(NetworkConfig.Config, "WAIT_FOR_INTERFACES", 0),
              40
            )
          Ops.set(NetworkConfig.Config, "WAIT_FOR_INTERFACES", 40)
        end
      end

      true
    end

    # Returns hash of NTP servers
    #
    # Provides map with NTP servers obtained via any of dhcp aware interfaces
    #
    # @return [Hash<String, Array<String>] key is device name, value
    #                                      is list of ntp servers obtained from the device
    def dhcp_ntp_servers
      dhcp_ifaces = find_dhcp_ifaces

      result = dhcp_ifaces.map { |iface| [iface, parse_ntp_servers(iface)] }.to_h
      result.delete_if { |_, ntps| ntps.empty? }
    end

    # This helper allows YARD to extract DSL-defined attributes.
    # Unfortunately YARD has problems with the Capitalized ones,
    # so those must be done manually.
    # @!macro [attach] publish_variable
    #  @!attribute $1
    #  @return [$2]
    def self.publish_variable(name, type)
      publish variable: name, type: type
    end

    # Adds a new interface with the given name
    #
    # @todo This method exists just to keep some compatibility during
    #       the migration to network-ng.
    def add_device_to_routing(name = current_name)
      config = yast_config
      return if config.nil?
      return if config.interfaces.any? { |i| i.name == name }

      yast_config.interfaces << Y2Network::Interface.new(name)
    end

    # Assigns all the routes from one interface to another
    #
    # @param from [String] interface belonging the routes to be moved
    # @param to [String] target interface
    def move_routes(from, to)
      config = yast_config
      return unless config&.routing

      routing = config.routing
      add_device_to_routing(to)
      target_interface = config.interfaces.by_name(to)
      return unless target_interface

      routing.routes.select { |r| r.interface && r.interface.name == from }
        .each { |r| r.interface = target_interface }
    end

  private

    # Searches available items according sysconfig option
    #
    # Expects a block. The block is provided
    # with a hash of every item's ifcfg options. Returns
    # list of device names for whose the block evaluates to true.
    #
    # ifcfg hash<string, string> is in form { <sysconfig_key> -> <value> }
    #
    # @return [Array<String>] list of device names
    def find_by_sysconfig
      items = GetNetcardInterfaces().select do |iface|
        ifcfg = GetDeviceMap(iface) || {}

        yield(ifcfg)
      end

      GetDeviceNames(items)
    end

    # Convenience method
    #
    # @todo It should not be called outside this module.
    # @return [Y2Network::Config] YaST network configuration
    def yast_config
      Y2Network::Config.find(:yast)
    end

    # @attribute Items
    # @return [Hash<Integer, Hash<String, Object> >]
    # Each item, indexed by an Integer in a Hash, aggregates several aspects
    # of a network interface. These aspects are in the inner Hash
    # which mostly has other hashes as values:
    #
    # - ifcfg: String, just a foreign key for NetworkInterfaces#Select
    # - hwinfo: Hash, detected hardware information
    # - udev: Hash, udev naming rules
    publish_variable :Items, "map <integer, any>"
    # @attribute Hardware
    publish_variable :Hardware, "list <map>"
    publish_variable :udev_net_rules, "map <string, any>"
    publish_variable :driver_options, "map <string, any>"
    publish_variable :autoinstall_settings, "map"
    publish_variable :operation, "symbol"
    publish_variable :description, "string"
    publish_variable :type, "string"
    # note: read-only param. Any modification is ignored.
    publish_variable :device, "string"
    publish_variable :alias, "string"
    # the index into {#Items}
    publish_variable :current, "integer"
    publish_variable :hotplug, "string"
    # @attribute Requires
    publish_variable :Requires, "list <string>"
    publish_variable :set_default_route, "boolean"
    publish_variable :qeth_portnumber, "string"
    publish_variable :chan_mode, "string"
    publish_variable :qeth_options, "string"
    publish_variable :ipa_takeover, "boolean"
    publish_variable :iucv_user, "string"
    publish_variable :qeth_layer2, "boolean"
    publish_variable :qeth_macaddress, "string"
    publish_variable :qeth_chanids, "string"
    publish_variable :lcs_timeout, "string"
    publish_variable :aliases, "map"
    publish_variable :tunnel_set_owner, "string"
    publish_variable :tunnel_set_group, "string"
    publish_variable :proposal_valid, "boolean"
    publish function: :GetLanItem, type: "map (integer)"
    publish function: :getCurrentItem, type: "map ()"
    publish function: :IsItemConfigured, type: "boolean (integer)"
    publish function: :GetDeviceName, type: "string (integer)"
    publish function: :GetDeviceType, type: "string (integer)"
    publish function: :GetDeviceMap, type: "map <string, any> (integer)"
    publish function: :GetModified, type: "boolean ()"
    publish function: :SetModified, type: "void ()"
    publish function: :Read, type: "void ()"
    publish function: :isCurrentHotplug, type: "boolean ()"
    publish function: :isCurrentDHCP, type: "boolean ()"
    publish function: :Commit, type: "boolean ()"
    publish function: :find_dhcp_ifaces, type: "list <string> ()"
  end

  LanItems = LanItemsClass.new
  LanItems.main
end
