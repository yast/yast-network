# encoding: utf-8

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
require "network/install_inf_convertor"
require "network/wicked"
require "network/lan_items_summary"
require "y2network/config"
require "y2network/boot_protocol"

require "shellwords"

module Yast
  # Does way too many things.
  #
  # 1. Aggregates data about network interfaces, both configured
  # and unconfigured, in {#Items}, which see.
  #
  # 2. Provides direct access to individual items of ifcfg files.
  # For example BOOTPROTO and STARTMODE are accessible in
  # {#bootproto} and {#startmode} (set via {#SetDeviceVars}
  # via {#Select} or {#SetItem}). The reverse direction (putting
  # the individual values back to an item) is {#Commit}.
  #
  # 3. ...
  #

  # FIXME: well this class really is not nice
  class LanItemsClass < Module
    include Logger
    include Wicked

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "NetworkInterfaces"
      Yast.import "ProductFeatures"
      Yast.import "NetworkConfig"
      Yast.import "Host"
      Yast.import "Directory"
      Yast.import "Stage"
      Yast.include self, "network/complex.rb"
      Yast.include self, "network/routines.rb"
      Yast.include self, "network/lan/s390.rb"
      Yast.include self, "network/lan/udev.rb"
      Yast.include self, "network/lan/bridge.rb"

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

      # in special cases when rcnetwork reload is not enought
      @force_restart = false

      @description = ""

      @type = ""
      # ifcfg name for the @current device
      @device = ""
      @current = -1
      @hotplug = ""

      @Requires = []

      # address options
      # boot protocol: BOOTPROTO
      @bootproto = "static"
      @ipaddr = ""
      @netmask = ""
      @prefix = ""

      @startmode = "auto"

      # wireless options
      @wl_mode = ""
      @wl_essid = ""
      @wl_nwid = ""
      @wl_auth_mode = ""
      # when adding another key, don't forget the chmod 600 in NetworkInterfaces
      @wl_wpa_psk = ""
      @wl_key_length = ""
      @wl_key = []
      @wl_default_key = 0
      @wl_nick = ""

      # FIXME: We should unify bridge_ports and bond_slaves variables

      # interfaces attached to bridge (list delimited by ' ')
      @bridge_ports = ""

      # bond options
      @bond_slaves = []
      @bond_option = ""

      # VLAN option
      @vlan_etherdevice = ""

      # wl_wpa_eap aggregates the settings in a map for easier CWM access.
      #
      # **Structure:**
      #
      #     wpa_eap
      #      WPA_EAP_MODE: string ("TTLS" "PEAP" or "TLS")
      #      WPA_EAP_IDENTITY: string
      #      WPA_EAP_PASSWORD: string (for TTLS and PEAP)
      #      WPA_EAP_ANONID: string (for TTLS and PEAP)
      #      WPA_EAP_CLIENT_CERT: string (for TLS, file name)
      #      WPA_EAP_CLIENT_KEY: string (for TLS, file name)
      #      WPA_EAP_CLIENT_KEY_PASSWORD: string (for TLS)
      #      WPA_EAP_CA_CERT: string (file name)
      #      WPA_EAP_AUTH: string ("", "MD5", "GTC", "CHAP"*, "PAP"*, "MSCHAP"*, "MSCHAPV2") (*: TTLS only)
      #      WPA_EAP_PEAP_VERSION: string ("", "0", "1")
      @wl_wpa_eap = {}
      @wl_channel = ""
      @wl_frequency = ""
      @wl_bitrate = ""
      @wl_accesspoint = ""
      @wl_power = true
      @wl_ap_scanmode = ""

      # Card Features from hwinfo
      # if not provided, we use the default full list
      @wl_auth_modes = nil
      @wl_enc_modes = nil
      @wl_channels = nil
      @wl_bitrates = nil

      # s390 options
      @qeth_portname = ""
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

      Yast.include self, "network/hardware.rb"

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

    # Returns true if current (see LanItems::current) has
    # configuration
    def IsCurrentConfigured
      IsItemConfigured(@current)
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

    # Convenience method to obtain the current Item udev rule
    #
    # @return [Array<String>] Item udev rule
    def current_udev_rule
      LanItems.GetItemUdevRule(LanItems.current)
    end

    # Returns name which is going to be used in the udev rule
    def current_udev_name
      if LanItems.current_renamed?
        LanItems.current_renamed_to
      else
        LanItems.GetItemUdev("NAME")
      end
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

    # Return the current device names
    #
    # @ return [Array<String>]
    def current_device_names
      GetNetcardInterfaces().map { |i| current_name_for(i) }.reject(&:empty?)
    end

    # Returns device name for current lan item (see LanItems::current)
    def GetCurrentName
      GetDeviceName(@current)
    end

    # Returns device type for particular lan item
    #
    # @param itemId [Integer] a key for {#Items}
    def GetDeviceType(itemId)
      NetworkInterfaces.GetType(GetDeviceName(itemId))
    end

    # Returns device type for current lan item (see LanItems::current)
    def GetCurrentType
      GetDeviceType(@current)
    end

    # Returns ifcfg configuration for particular item
    #
    # @param itemId [Integer] a key for {#Items}
    def GetDeviceMap(itemId)
      return nil if !IsItemConfigured(itemId)

      NetworkInterfaces.devmap(GetDeviceName(itemId))
    end

    def GetCurrentMap
      GetDeviceMap(@current)
    end

    # Sets item's sysconfig device map to given one
    #
    # It updates NetworkInterfaces according given map. Map is expected
    # to be a hash where both key even value are strings
    #
    # @param item_id [Integer] a key for {#Items}
    def SetDeviceMap(item_id, devmap)
      devname = GetDeviceName(item_id)
      return false if devname.nil? || devname.empty?

      NetworkInterfaces.Change2(devname, devmap, false)
    end

    # Sets one option in items sysconfig device map
    #
    # Currently no checks on sysconfig option validity are performed
    #
    # @param item_id [Integer] a key for {#Items}
    def SetItemSysconfigOpt(item_id, opt, value)
      devmap = GetDeviceMap(item_id)
      return false if devmap.nil?

      devmap[opt] = value
      SetDeviceMap(item_id, devmap)
    end

    # Returns udev rule known for particular item
    #
    # @param itemId [Integer] a key for {#Items}
    def GetItemUdevRule(itemId)
      Ops.get_list(GetLanItem(itemId), ["udev", "net"], [])
    end

    # Sets udev rule for given item
    #
    # @param itemId [Integer] a key for {#Items}
    # @param rule   [String]  an udev rule
    def SetItemUdevRule(itemId, rule)
      GetLanItem(itemId)["udev"]["net"] = rule
    end

    # Inits item's udev rule to a default one if none is present
    #
    # @param item_id [Integer] a key for {#Items}
    # @return [String] item's udev rule
    def InitItemUdevRule(item_id)
      udev = GetItemUdevRule(item_id)
      return udev if !udev.empty?

      default_mac = GetLanItem(item_id).fetch("hwinfo", {})["permanent_mac"]
      raise ArgumentError, "Cannot propose udev rule - NIC not present" if !default_mac

      default_udev = GetDefaultUdevRule(
        GetDeviceName(item_id),
        default_mac
      )
      SetItemUdevRule(item_id, default_udev)

      default_udev
    end

    def ReadUdevDriverRules
      Builtins.y2milestone("Reading udev rules ...")
      @udev_net_rules = Convert.convert(
        SCR.Read(path(".udev_persistent.net")),
        from: "any",
        to:   "map <string, any>"
      )

      Builtins.y2milestone("Reading driver options ...")
      Builtins.foreach(SCR.Dir(path(".modules.options"))) do |driver|
        pth = Builtins.sformat(".modules.options.%1", driver)
        Builtins.foreach(
          Convert.convert(
            SCR.Read(Builtins.topath(pth)),
            from: "any",
            to:   "map <string, string>"
          )
        ) do |key, value|
          Ops.set(
            @driver_options,
            driver,
            Builtins.sformat(
              "%1%2%3=%4",
              Ops.get_string(@driver_options, driver, ""),
              if Ops.greater_than(
                Builtins.size(Ops.get_string(@driver_options, driver, "")),
                0
              )
                " "
              else
                ""
              end,
              key,
              value
            )
          )
        end
      end

      true
    end

    def getUdevFallback
      udev_rules = Ops.get_list(getCurrentItem, ["udev", "net"], [])

      if IsEmpty(udev_rules)
        udev_rules = GetDefaultUdevRule(
          GetCurrentName(),
          Ops.get_string(getCurrentItem, ["hwinfo", "permanent_mac"], "")
        )
        Builtins.y2milestone(
          "No Udev rules found, creating default: %1",
          udev_rules
        )
      end

      deep_copy(udev_rules)
    end

    # It returns a value for the particular key of udev rule belonging to the current item.
    def GetItemUdev(key)
      udev_key_value(getUdevFallback, key)
    end

    # It deletes the given key from the udev rule of the current item.
    #
    # @param key [string] udev key which identifies the tuple to be removed
    # @return [Object, nil] the current item's udev rule without the given key; nil if
    # there is not udev rules for the current item
    def RemoveItemUdev(key)
      return nil if current_udev_rule.empty?

      log.info("Removing #{key} from #{current_udev_rule}")
      Items()[@current]["udev"]["net"] =
        LanItems.RemoveKeyFromUdevRule(current_udev_rule, key)
    end

    # Updates the udev rule of the current Lan Item based on the key given
    # which currently could be mac or bus_id.
    #
    # In case of bus_id the dev_port will be always added to avoid cases where
    # the interfaces shared the same bus_id (i.e. Multiport cards using the
    # same function to all the ports) (bsc#1007172)
    #
    # @param based_on [Symbol] principal key to be matched, `:mac` or `:bus_id`
    # @return [void]
    def update_item_udev_rule!(based_on = :mac)
      new_rule = current_udev_rule.empty?
      LanItems.InitItemUdevRule(LanItems.current) if new_rule

      case based_on
      when :mac
        return if new_rule

        LanItems.RemoveItemUdev("ATTR{dev_port}")

        # FIXME: While the user is able to modify the udev rule using the
        # mac address instead of bus_id when bonding, could be that the
        # mac in use was not the permanent one. We could read it with
        # ethtool -P dev_name}
        LanItems.ReplaceItemUdev(
          "KERNELS",
          "ATTR{address}",
          LanItems.getCurrentItem.fetch("hwinfo", {}).fetch("permanent_mac", "")
        )
      when :bus_id
        # Update or insert the dev_port if the sysfs dev_port attribute is present
        LanItems.ReplaceItemUdev(
          "ATTR{dev_port}",
          "ATTR{dev_port}",
          LanItems.dev_port(LanItems.GetCurrentName)
        ) if LanItems.dev_port?(LanItems.GetCurrentName)

        # If the current rule is mac based, overwrite to bus id. Don't touch otherwise.
        LanItems.ReplaceItemUdev(
          "ATTR{address}",
          "KERNELS",
          LanItems.getCurrentItem.fetch("hwinfo", {}).fetch("busid", "")
        )
      else
        raise ArgumentError, "The key given for udev rule #{based_on} is not supported"
      end
    end

    # It replaces a tuple identified by replace_key in current item's udev rule
    #
    # Note that the tuple is identified by key only. However modification flag is
    # set only if value was changed (in case when replace_key == new_key)
    #
    # It also contain a logic on tuple operators. When the new_key is "NAME"
    # then assignment operator (=) is used. Otherwise equality operator (==) is used.
    # Thats bcs this function is currently used for touching "NAME", "KERNELS" and
    # `ATTR{address}` keys only
    #
    # @param replace_key [string] udev key which identifies tuple to be replaced
    # @param new_key     [string] new key to by used
    # @param new_val     [string] value for new key
    # @return updated rule when replace_key is found, current rule otherwise
    def ReplaceItemUdev(replace_key, new_key, new_val)
      # =    for assignment
      # ==   for equality checks
      operator = new_key == "NAME" ? "=" : "=="
      rule = RemoveKeyFromUdevRule(getUdevFallback, replace_key)

      # NAME="devname" has to be last in the rule.
      # otherwise SCR agent .udev_persistent.net returns crap
      # isn't that fun
      name_tuple = rule.pop
      new_rule = AddToUdevRule(rule, "#{new_key}#{operator}\"#{new_val}\"")
      new_rule.push(name_tuple)

      if current_udev_rule.sort != new_rule.sort
        SetModified()

        log.info("ReplaceItemUdev: new udev rule = #{new_rule}")

        Items()[@current]["udev"] = { "net" => [] } if !Items()[@current]["udev"]
        Items()[@current]["udev"]["net"] = new_rule
      end

      deep_copy(new_rule)
    end

    # Updates device name.
    #
    # It updates device's udev rules and config name.
    # Updating config name means that old configuration is deleted from
    # the system.
    #
    # @param itemId [Integer] a key for {#Items}
    #
    # Returns new name
    def SetItemName(itemId, name)
      lan_items = LanItems.Items

      if name && !name.empty?
        if lan_items[itemId]["udev"]
          updated_rule = update_udev_rule_key(GetItemUdevRule(itemId), "NAME", name)
          lan_items[itemId]["udev"]["net"] = updated_rule
        end
      else
        # rewrite rule for empty name is meaningless
        lan_items[itemId].delete("udev")
      end

      if lan_items[itemId].key?("ifcfg")
        NetworkInterfaces.Delete2(lan_items[itemId]["ifcfg"])
        lan_items[itemId]["ifcfg"] = name.to_s
      end

      name
    end

    # Updates current device name.
    #
    # It updates device's udev rules and config name.
    # Updating config name means that old configuration is deleted from
    # the system.
    #
    # Returns new name
    def SetCurrentName(name)
      SetItemName(@current, name)
    end

    # Sets new device name for current item
    def rename(name)
      if GetCurrentName() != name
        @Items[@current]["renamed_to"] = name
        SetModified()
      else
        @Items[@current].delete("renamed_to")
      end
    end

    # Returns new name for current item
    #
    # @param item_id [Integer] a key for {#Items}
    def renamed_to(item_id)
      Items()[item_id]["renamed_to"]
    end

    def current_renamed_to
      renamed_to(@current)
    end

    # Tells if current item was renamed
    #
    # @param item_id [Integer] a key for {#Items}
    def renamed?(item_id)
      return false if !renamed_to(item_id)
      renamed_to(item_id) != GetDeviceName(item_id)
    end

    def current_renamed?
      renamed?(@current)
    end

    # Writes udev rules for all items.
    #
    # Currently only interesting change is renaming interface.
    def WriteUdevItemsRules
      # loop over all items and checks if device name has changed
      net_rules = []

      Builtins.foreach(
        Convert.convert(
          Map.Keys(@Items),
          from: "list",
          to:   "list <integer>"
        )
      ) do |key|
        item_udev_net = GetItemUdevRule(key)
        next if IsEmpty(item_udev_net)
        dev_name = Ops.get_string(@Items, [key, "hwinfo", "dev_name"], "")
        @current = key
        if dev_name != GetItemUdev("NAME")
          # when changing device name you have a choice
          # - change kernel "match rule", or
          # - remove it completely
          # removing is less error prone when tracking name changes, so it was chosen.
          item_udev_net = RemoveKeyFromUdevRule(item_udev_net, "KERNEL")
          # setting links down during AY is forbidden bcs it can freeze ssh installation
          SetIfaceDown(dev_name) if !Mode.autoinst

          @force_restart = true
        end
        net_rules = Builtins.add(
          net_rules,
          Builtins.mergestring(item_udev_net, ", ")
        )
      end

      Builtins.y2milestone("write net udev rules: %1", net_rules)

      write_update_udevd(net_rules)

      true
    end

    def WriteUdevDriverRules
      udev_drivers_rules = {}

      Builtins.foreach(
        Convert.convert(
          Map.Keys(@Items),
          from: "list",
          to:   "list <integer>"
        )
      ) do |key|
        driver = Ops.get_string(@Items, [key, "udev", "driver"], "")
        if IsNotEmpty(driver)
          modalias = Ops.get_string(@Items, [key, "hwinfo", "modalias"], "")
          driver_rule = []

          driver_rule = AddToUdevRule(
            driver_rule,
            Builtins.sformat("ENV{MODALIAS}==\"%1\"", modalias)
          )
          driver_rule = AddToUdevRule(
            driver_rule,
            Builtins.sformat("ENV{MODALIAS}=\"%1\"", driver)
          )

          Ops.set(udev_drivers_rules, driver, driver_rule)
        end
      end

      Builtins.y2milestone("write drivers udev rules: %1", udev_drivers_rules)

      SCR.Write(path(".udev_persistent.drivers"), udev_drivers_rules)

      # write rules from driver
      Builtins.foreach(
        Convert.convert(
          @driver_options,
          from: "map <string, any>",
          to:   "map <string, string>"
        )
      ) do |key, value|
        val = {}
        Builtins.foreach(Builtins.splitstring(value, " ")) do |k|
          l = Builtins.splitstring(k, "=")
          Ops.set(val, Ops.get(l, 0, ""), Ops.get(l, 1, ""))
        end
        val = nil if IsEmpty(value)
        SCR.Write(Builtins.add(path(".modules.options"), key), val)
      end

      SCR.Write(path(".modules"), nil)

      nil
    end

    def WriteUdevRules
      WriteUdevItemsRules()
      WriteUdevDriverRules()

      # wait so that ifcfgs written in NetworkInterfaces are newer
      # (1-second-wise) than netcontrol status files,
      # and rcnetwork reload actually works (bnc#749365)
      SCR.Execute(path(".target.bash"), "/usr/bin/udevadm settle")
      sleep(1)

      nil
    end

    def write
      renamed_items = @Items.keys.select { |item_id| renamed?(item_id) }
      renamed_items.each do |item_id|
        devmap = GetDeviceMap(item_id)
        # change configuration name if device is configured
        NetworkInterfaces.Change2(renamed_to(item_id), devmap, false) if devmap
        SetItemName(item_id, renamed_to(item_id))
      end

      LanItems.WriteUdevRules if !Stage.cont && InstallInfConvertor.instance.AllowUdevModify
    end

    # Exports configuration for use in AY profile
    #
    # TODO: it currently exports only udevs (as a consequence of dropping LanUdevAuto)
    # so once it is extended, all references has to be checked
    def export(devices)
      export_udevs(devices)
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

    def AddNew
      @current = @Items.to_h.size
      # Items[@current] is expected to always exist
      @Items[@current] = {}
      @operation = :add

      nil
    end

    # return list of available modules for current device
    # with default default_module (on first possition)

    def GetItemModules(default_module)
      mods = []
      mods = Builtins.add(mods, default_module) if IsNotEmpty(default_module)
      Builtins.foreach(
        Ops.get_list(@Items, [@current, "hwinfo", "drivers"], [])
      ) do |row|
        tmp_mod = Ops.get_string(row, ["modules", 0, 0], "")
        mods = Builtins.add(mods, tmp_mod) if !Builtins.contains(mods, tmp_mod)
      end
      deep_copy(mods)
    end

    # Creates list of all known netcard items
    #
    # It means list of item ids of all netcards which are detected and/or
    # configured in the system
    def GetNetcardInterfaces
      Items().keys
    end

    # Creates list of names of all known netcards configured even unconfigured
    def GetNetcardNames
      GetDeviceNames(GetNetcardInterfaces())
    end

    # Finds all items of given device type
    #
    # @param type [String] device type
    # @return [Array] list of device names
    def find_type_ifaces(type)
      items = GetNetcardInterfaces().select do |iface|
        GetDeviceType(iface) == type
      end

      GetDeviceNames(items)
    end

    # Finds all NICs configured with DHCP
    #
    # @return [Array<String>] list of NIC names which are configured to use (any) dhcp
    def find_dhcp_ifaces
      find_by_sysconfig { |ifcfg| dhcp?(ifcfg) }
    end

    # Find all NICs configured statically
    #
    # @return [Array<String>] list of NIC names which have a static config
    def find_static_ifaces
      find_by_sysconfig do |ifcfg|
        ifcfg.fetch("BOOTPROTO", "").match(/static/i)
      end
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

    # Get list of all configured interfaces
    #
    # @param type [String] only obtains configured interfaces of the given type
    # return [Array] list of strings - interface names (eth0, ...)
    # FIXME: rename e.g. to configured_interfaces
    def getNetworkInterfaces(type = nil)
      configurations = NetworkInterfaces.FilterDevices("netcard")
      devtypes = type ? [type] : NetworkInterfaces.CardRegex["netcard"].to_s.split("|")

      devtypes.inject([]) do |acc, conf_type|
        conf = configurations[conf_type].to_h
        acc.concat(conf.keys)
      end
    end

    # Finds item_id by device name
    #
    # If an item is associated with config file of given name (ifcfg-<device>)
    # then its id is returned
    #
    # @param [String] device name (e.g. eth0)
    # @return index in Items or nil
    def find_configured(device)
      @Items.select { |_k, v| v["ifcfg"] == device }.keys.first
    end

    def FindAndSelect(device)
      item_id = find_configured(device)
      @current = item_id if item_id

      !item_id.nil?
    end

    # search all known devices to find it's index in Items array
    #
    # @param [String] device matched with item[ "hwinfo", "dev_name"]
    # @return index in Items or -1 if not found
    def FindDeviceIndex(device)
      ret = -1

      Builtins.foreach(
        Convert.convert(
          @Items,
          from: "map <integer, any>",
          to:   "map <integer, map <string, any>>"
        )
      ) do |i, a|
        if Ops.get_string(a, ["hwinfo", "dev_name"], "") == device
          ret = i
          raise Break
        end
      end

      ret
    end

    # It finds a new style device name for device name in old fashioned format
    #
    # It goes through currently present devices and tries to mach it to given
    # old fashioned name
    #
    # @return [String] new style name in case of success. Given name otherwise.
    def getDeviceName(oldname)
      newname = oldname

      hardware = ReadHardware("netcard")

      hardware.each do |hw|
        hw_dev_name = hw["dev_name"] || ""
        hw_dev_mac = hw["permanent_mac"] || ""
        hw_dev_busid = hw["busid"] || ""

        case oldname
        when /.*-id-#{hw_dev_mac}/i
          log.info("device by ID found: #{oldname}")
          newname = hw_dev_name
        when /.*-bus-#{hw_dev_busid}/i
          log.info("device by BUS found #{oldname}")
          newname = hw_dev_name
        end
      end

      log.info("nothing changed, #{newname} is old style dev_name") if oldname == newname

      newname
    end

    # preinitializates @Items according info on physically detected network cards
    def ReadHw
      @Items = {}
      @Hardware = ReadHardware("netcard")
      # Hardware = [$["active":true, "bus":"pci", "busid":"0000:02:00.0", "dev_name":"wlan0", "drivers":[$["active":true, "modprobe":true, "modules":[["ath5k" , ""]]]], "link":true, "mac":"00:22:43:37:55:c3", "modalias":"pci:v0000168Cd0000001Csv00001A3Bsd00001026bc02s c00i00", "module":"ath5k", "name":"AR242x 802.11abg Wireless PCI Express Adapter", "num":0, "options":"", "re quires":[], "sysfs_id":"/devices/pci0000:00/0000:00:1c.1/0000:02:00.0", "type":"wlan", "udi":"/org/freedeskto p/Hal/devices/pci_168c_1c", "wl_auth_modes":["open", "sharedkey", "wpa-psk", "wpa-eap"], "wl_bitrates":nil, " wl_channels":["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"], "wl_enc_modes":["WEP40", "WEP104", "T KIP", "CCMP"]], $["active":true, "bus":"pci", "busid":"0000:01:00.0", "dev_name":"eth0", "drivers":[$["active ":true, "modprobe":true, "modules":[["atl1e", ""]]]], "link":false, "mac":"00:23:54:3f:7c:c3", "modalias":"pc i:v00001969d00001026sv00001043sd00008324bc02sc00i00", "module":"atl1e", "name":"L1 Gigabit Ethernet Adapter", "num":1, "options":"", "requires":[], "sysfs_id":"/devices/pci0000:00/0000:00:1c.3/0000:01:00.0", "type":"et h", "udi":"/org/freedesktop/Hal/devices/pci_1969_1026", "wl_auth_modes":nil, "wl_bitrates":nil, "wl_channels" :nil, "wl_enc_modes":nil]];
      ReadUdevDriverRules()

      udev_drivers_rules = Convert.convert(
        SCR.Read(path(".udev_persistent.drivers")),
        from: "any",
        to:   "map <string, any>"
      )
      Builtins.foreach(@Hardware) do |hwitem|
        udev_net = if Ops.get_string(hwitem, "dev_name", "") != ""
          Ops.get_list(
            @udev_net_rules,
            Ops.get_string(hwitem, "dev_name", ""),
            []
          )
        else
          []
        end
        mod = Builtins.deletechars(
          Ops.get(
            Builtins.splitstring(
              Ops.get(
                Ops.get_list(
                  udev_drivers_rules,
                  Ops.get_string(hwitem, "modalias", ""),
                  []
                ),
                1,
                ""
              ),
              "="
            ),
            1,
            ""
          ),
          "\""
        )
        Ops.set(
          @Items,
          Builtins.size(@Items),
          "hwinfo" => hwitem,
          "udev"   => { "net" => udev_net, "driver" => mod }
        )
      end

      nil
    end

    # initializates @Items
    #
    # It does:
    # (1) read hardware present on the system
    # (2) read known configurations (e.g. ifcfg-eth0)
    # (3) joins together. Join is done via device name (e.g. eth0) as key.
    # It is full outer join in -> you can have hwinfo part with no coresponding
    # netconfig part (or vice versa) in @Items when the method is done.
    def Read
      reset_cache

      system_config = Y2Network::Config.from(:sysconfig)
      Yast::Lan.add_config(:system, system_config)
      Yast::Lan.add_config(:yast, system_config.copy)
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

      @autoinstall_settings["start_immediately"] = settings.fetch("start_immediately", false)
      @autoinstall_settings["strict_IP_check_timeout"] = settings.fetch("strict_IP_check_timeout", -1)
      @autoinstall_settings["keep_install_network"] = settings.fetch("keep_install_network", true)

      # FIXME: createS390Device does two things, it
      # - updates internal structures
      # - creates s390 device eth emulation
      # So, it belongs partly into Import and partly into Write. Note, that
      # the code is currently unable to revert already created emulated device.
      settings.fetch("s390-devices", {}).each { |rule| createS390Device(rule) } if Arch.s390

      # settings == {} has special meaning 'Reset' used by AY
      SetModified() if !settings.empty?

      true
    end

    def GetDescr
      descr = []
      Builtins.foreach(
        Convert.convert(
          @Items,
          from: "map <integer, any>",
          to:   "map <integer, map <string, any>>"
        )
      ) do |key, value|
        if Builtins.haskey(value, "table_descr") &&
            Ops.greater_than(
              Builtins.size(Ops.get_map(@Items, [key, "table_descr"], {})),
              1
            )
          descr = Builtins.add(
            descr,
            "id"          => key,
            "rich_descr"  => Ops.get_string(
              @Items,
              [key, "table_descr", "rich_descr"],
              ""
            ),
            "table_descr" => Ops.get_list(
              @Items,
              [key, "table_descr", "table_descr"],
              []
            )
          )
        end
      end
      deep_copy(descr)
    end

    def needFirmwareCurrentItem
      need = false
      if IsNotEmpty(Ops.get_string(@Items, [@current, "hwinfo", "driver"], ""))
        if Builtins.haskey(
          @request_firmware,
          Ops.get_string(@Items, [@current, "hwinfo", "driver"], "")
        )
          need = true
        end
      else
        Builtins.foreach(
          Ops.get_list(@Items, [@current, "hwinfo", "drivers"], [])
        ) do |driver|
          if Builtins.haskey(
            @request_firmware,
            Ops.get_string(driver, ["modules", 0, 0], "")
          )
            Builtins.y2milestone(
              "driver %1 needs firmware",
              Ops.get_string(driver, ["modules", 0, 0], "")
            )
            need = true
          end
        end
      end
      Builtins.y2milestone("item %1 needs firmware:%2", @current, need)
      need
    end

    def GetFirmwareForCurrentItem
      kernel_module = ""
      if IsNotEmpty(Ops.get_string(@Items, [@current, "hwinfo", "driver"], ""))
        if Builtins.haskey(
          @request_firmware,
          Ops.get_string(@Items, [@current, "hwinfo", "driver"], "")
        )
          kernel_module = Ops.get_string(
            @Items,
            [@current, "hwinfo", "driver"],
            ""
          )
        end
      else
        Builtins.foreach(
          Ops.get_list(@Items, [@current, "hwinfo", "drivers"], [])
        ) do |driver|
          if Builtins.haskey(
            @request_firmware,
            Ops.get_string(driver, ["modules", 0, 0], "")
          )
            kernel_module = Ops.get_string(driver, ["modules", 0, 0], "")
            raise Break
          end
        end
      end
      firmware = Ops.get(@request_firmware, kernel_module, "")
      Builtins.y2milestone(
        "driver %1 needs firmware %2",
        kernel_module,
        firmware
      )

      firmware
    end

    # Creates item's startmode human description
    #
    # @param item_id [Integer] a key for {#Items}
    def startmode_overview(item_id)
      startmode_descrs = {
        # summary description of STARTMODE=auto
        "auto"    => _(
          "Started automatically at boot"
        ),
        # summary description of STARTMODE=auto
        "onboot"  => _(
          "Started automatically at boot"
        ),
        # summary description of STARTMODE=hotplug
        "hotplug" => _(
          "Started automatically at boot"
        ),
        # summary description of STARTMODE=nfsroot
        "nfsroot" => _(
          "Started automatically at boot"
        ),
        # summary description of STARTMODE=ifplugd
        "ifplugd" => _(
          "Started automatically on cable connection"
        ),
        # summary description of STARTMODE=managed
        "managed" => _(
          "Managed by NetworkManager"
        ),
        # summary description of STARTMODE=off
        "off"     => _(
          "Will not be started at all"
        )
      }

      ifcfg = GetDeviceMap(item_id) || {}
      startmode_descr = startmode_descrs[ifcfg["STARTMODE"].to_s] || _("Started manually")

      [startmode_descr]
    end

    # Creates a summary of the configured items.
    #
    # It supports differents types of summaries depending on the options[:type]
    #
    # @see LanItemsSummary
    # @param type [String,Symbol] summary options, supported "one-line" and "proposal"
    # @return [String] summary of the configured items
    def summary(type)
      LanItemsSummary.new.send(type)
    end

    # Creates details for device's overview based on ip configuration type
    #
    # Produces list of strings. Strings are intended for "bullet" list, e.g.:
    # * <string1>
    # * <string2>
    #
    # @param [Hash] dev_map a device's sysconfig map (in form "option" => "value")
    # @return [Array] list of strings, one string is intended for one "bullet"
    def ip_overview(dev_map)
      bullets = []

      ip = DeviceProtocol(dev_map)

      if ip =~ /DHCP/
        bullets << format("%s %s", _("IP address assigned using"), ip)
      elsif IP.Check(ip)
        prefixlen = dev_map["PREFIXLEN"] || ""
        if !prefixlen.empty?
          bullets << format(_("IP address: %s/%s"), ip, prefixlen)
        else
          subnetmask = dev_map["NETMASK"]
          bullets << format(_("IP address: %s, subnet mask %s"), ip, subnetmask)
        end
      end

      # build aliases overview
      item_aliases = dev_map["_aliases"] || {}
      if !item_aliases.empty? && !NetworkService.is_network_manager
        item_aliases.each do |_key2, desc|
          parameters = format("%s/%s", desc["IPADDR"], desc["PREFIXLEN"])
          bullets << format("%s (%s)", desc["LABEL"], parameters)
        end
      end

      bullets
    end

    # FIXME: side effect: sets @type. No reason for that. It should only build item
    #   overview. Check and remove.
    def BuildLanOverview
      overview = []
      links = []

      LanItems.Items.each_key do |key|
        rich = ""

        item_hwinfo = LanItems.Items[key]["hwinfo"] || {}
        descr = item_hwinfo["name"] || ""

        note = ""
        bullets = []
        ifcfg_name = LanItems.Items[key]["ifcfg"] || ""
        ifcfg_type = NetworkInterfaces.GetType(ifcfg_name)

        if !ifcfg_name.empty?
          ifcfg_conf = GetDeviceMap(key)
          log.error("BuildLanOverview: devmap for #{key}/#{ifcfg_name} is nil") if ifcfg_conf.nil?

          ifcfg_desc = ifcfg_conf["NAME"]
          descr = ifcfg_desc if !ifcfg_desc.nil? && !ifcfg_desc.empty?
          descr = CheckEmptyName(ifcfg_type, descr)
          status = DeviceStatus(ifcfg_type, ifcfg_name, ifcfg_conf)

          bullets << _("Device Name: %s") % ifcfg_name
          bullets += startmode_overview(key)
          bullets += ip_overview(ifcfg_conf) if ifcfg_conf["STARTMODE"] != "managed"

          if ifcfg_type == "wlan" &&
              ifcfg_conf["WIRELESS_AUTH_MODE"] == "open" &&
              IsEmpty(ifcfg_conf["WIRELESS_KEY_0"])

            # avoid colons
            ifcfg_name = ifcfg_name.tr(":", "/")
            href = "lan--wifi-encryption-" + ifcfg_name
            # interface summary: WiFi without encryption
            warning = HTML.Colorize(_("Warning: no encryption is used."), "red")
            # Hyperlink: Change the configuration of an interface
            status << " " << warning << " " << Hyperlink(href, _("Change."))
            links << href
          end

          if ifcfg_type == "bond" || ifcfg_type == "br"
            bullets << slaves_desc(ifcfg_type, ifcfg_name)
          end

          if enslaved?(ifcfg_name)
            if yast_config.interfaces.bond_index[ifcfg_name]
              master = yast_config.interfaces.bond_index[ifcfg_name]
              master_desc = _("Bonding master")
            else
              master = yast_config.interfaces.bridge_index[ifcfg_name]
              master_desc = _("Bridge")
            end
            note = format(_("enslaved in %s"), master)
            bullets << format("%s: %s", master_desc, master)
          end

          if renamed?(key)
            note = format("%s -> %s", GetDeviceName(key), renamed_to(key))
          end

          overview << Summary.Device(descr, status)
        else
          descr = CheckEmptyName(ifcfg_type, descr)
          overview << Summary.Device(descr, Summary.NotConfigured)
        end
        conn = ""
        conn = HTML.Bold(format("(%s)", _("Not connected"))) if !item_hwinfo["link"]
        conn = HTML.Bold(format("(%s)", _("No hwinfo"))) if item_hwinfo.empty?

        mac_dev = HTML.Bold("MAC : ") + item_hwinfo["permanent_mac"].to_s + "<br>"
        bus_id  = HTML.Bold("BusID : ") + item_hwinfo["busid"].to_s + "<br>"
        physical_port_id = HTML.Bold("PhysicalPortID : ") + physical_port_id(ifcfg_name) + "<br>"

        rich << " " << conn << "<br>" << mac_dev if IsNotEmpty(item_hwinfo["permanent_mac"])
        rich << bus_id if IsNotEmpty(item_hwinfo["busid"])
        rich << physical_port_id if physical_port_id?(ifcfg_name)
        # display it only if we need it, don't duplicate "ifcfg_name" above
        if IsNotEmpty(item_hwinfo["dev_name"]) && ifcfg_name.empty?
          dev_name = _("Device Name: %s") % item_hwinfo["dev_name"]
          rich << HTML.Bold(dev_name) << "<br>"
        end
        rich = HTML.Bold(descr) + rich
        if IsEmpty(item_hwinfo["dev_name"]) && !item_hwinfo.empty? && !Arch.s390
          rich << "<p>"
          rich << _("Unable to configure the network card because the kernel device (eth0, wlan0) is not present. This is mostly caused by missing firmware (for wlan devices). See dmesg output for details.")
          rich << "</p>"
        elsif !ifcfg_name.empty?
          rich << HTML.List(bullets)
        else
          rich << "<p>"
          rich << _("The device is not configured. Press <b>Edit</b>\nto configure.\n")
          rich << "</p>"

          curr = @current
          @current = key
          if needFirmwareCurrentItem
            fw = GetFirmwareForCurrentItem()
            rich << format("%s : %s", _("Needed firmware"), !fw.empty? ? fw : _("unknown"))
          end
          @current = curr
        end
        LanItems.Items[key]["table_descr"] = {
          "rich_descr"  => rich,
          "table_descr" => [descr, DeviceProtocol(ifcfg_conf), ifcfg_name, note]
        }
      end
      [Summary.DevicesList(overview), links]
    end

    # Create an overview table with all configured devices
    # @return table items
    def Overview
      BuildLanOverview()
      GetDescr()
    end

    # Is current device hotplug or not? I.e. is connected via usb/pcmci?
    def isCurrentHotplug
      hotplugtype = Ops.get_string(getCurrentItem, ["hwinfo", "hotplug"], "")
      hotplugtype == "usb" || hotplugtype == "pcmci"
    end

    # Check if currently edited device gets its IP address
    # from DHCP (v4, v6 or both)
    # @return true if it is
    def isCurrentDHCP
      return false unless @bootproto

      Y2Network::BootProtocol.from_name(@bootproto).dhcp?
    end

    # Checks whether given device configuration is set to use a dhcp bootproto
    #
    # ideally should replace @see isCurrentDHCP
    def dhcp?(devmap)
      return false unless devmap["BOOTPROTO"]

      Y2Network::BootProtocol.from_name(devmap["BOOTPROTO"]).dhcp?
    end

    def GetItemDescription
      Ops.get_string(@Items, [@current, "table_descr", "rich_descr"], "")
    end

    # Select the hardware component
    # @param hardware the component
    def SelectHWMap(hardware)
      hardware = deep_copy(hardware)
      sel = SelectHardwareMap(hardware)

      # common stuff
      @description = Ops.get_string(sel, "name", "")
      @type = Ops.get_string(sel, "type", "eth")
      @hotplug = Ops.get_string(sel, "hotplug", "")

      @Requires = Ops.get_list(sel, "requires", [])
      # #44977: Requires now contain the appropriate kernel packages
      # but they are handled differently due to multiple kernel flavors
      # (see Package::InstallKernel)
      # Leave only those not starting with "kernel".
      @Requires = Builtins.filter(@Requires) do |r|
        Builtins.search(r, "kernel") != 0
      end
      Builtins.y2milestone("requires=%1", @Requires)

      # FIXME: devname
      @hotplug = ""

      # Wireless Card Features
      @wl_auth_modes = Builtins.prepend(
        hardware["wl_auth_modes"],
        "no-encryption"
      )
      @wl_enc_modes = hardware["wl_enc_modes"]
      @wl_channels = hardware["wl_channels"]
      @wl_bitrates = hardware["wl_bitrates"]

      Builtins.y2milestone("hw=%1", hardware)

      @hw = deep_copy(hardware)
      if Arch.s390 && @operation == :add
        Builtins.y2internal("Propose chan_ids values for %1", @hw)
        devid = 0
        devstr = ""
        s390chanid = "[0-9]+\\.[0-9]+\\."
        if Builtins.regexpmatch(Ops.get_string(@hw, "busid", ""), s390chanid)
          devid = Builtins.tointeger(
            Ops.add(
              "0x",
              Builtins.regexpsub(
                Ops.get_string(@hw, "busid", ""),
                Ops.add(s390chanid, "(.*)"),
                "\\1"
              )
            )
          )
          devstr = Builtins.regexpsub(
            Ops.get_string(@hw, "busid", ""),
            Ops.add(Ops.add("(", s390chanid), ").*"),
            "\\1"
          )
        end

        Builtins.y2milestone("devid=%1(%2)", devid, devstr)
        devid = 0 if devid.nil?
        devid0 = String.PadZeros(
          Builtins.regexpsub(Builtins.tohexstring(devid), "0x(.*)", "\\1"),
          4
        )
        devid1 = String.PadZeros(
          Builtins.regexpsub(
            Builtins.tohexstring(Ops.add(devid, 1)),
            "0x(.*)",
            "\\1"
          ),
          4
        )
        devid2 = String.PadZeros(
          Builtins.regexpsub(
            Builtins.tohexstring(Ops.add(devid, 2)),
            "0x(.*)",
            "\\1"
          ),
          4
        )
        @qeth_chanids = if DriverType(@type) == "ctc" || DriverType(@type) == "lcs"
          Builtins.sformat("%1%2 %1%3", devstr, devid0, devid1)
        else
          Builtins.sformat(
            "%1%2 %1%3 %1%4",
            devstr,
            devid0,
            devid1,
            devid2
          )
        end
      end

      nil
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

      # TODO: is it still needed?
      SetModified()
      true
    end

    # Remove a half-configured item.
    # @return [true] so that this can be used for the :abort callback
    def Rollback
      log.info "rollback item #{@current}"
      # Do not delete elements that are :edited but does not contain hwinfo
      # yet (Add a virtual device and then edit it canceling the process during the
      # edition)
      if LanItems.operation == :add && getCurrentItem.fetch("hwinfo", {}).empty?
        LanItems.Items.delete(@current)
      elsif IsCurrentConfigured()
        if !getNetworkInterfaces.include?(getCurrentItem["ifcfg"])
          LanItems.Items[@current].delete("ifcfg")
        end
      end

      true
    end

    # Deletes item and its configuration
    #
    # Item for deletion is searched using device name
    def delete_dev(name)
      FindAndSelect(name)
      DeleteItem()
    end

    # Deletes the {#current} item and its configuration
    def DeleteItem
      return if @current < 0
      return if @Items.nil? || @Items.empty?

      log.info("DeleteItem: #{@Items[@current]}")

      devmap = GetCurrentMap()
      drop_hosts(devmap["IPADDR"]) if devmap
      # We have to remove it from routing before deleting the item
      remove_current_device_from_routing

      SetCurrentName("")

      current_item = @Items[@current]

      if current_item["hwinfo"].nil? || current_item["hwinfo"].empty?
        # size is always > 0 here and items are numbered 0, 1, ..., size -1
        delete_index = @Items.size - 1

        @Items[@current] = @Items[delete_index] if delete_index != @current
        @Items.delete(delete_index)

        # item was deleted, so original @current is invalid
        @current = -1
      end

      SetModified()

      nil
    end

    def SetItem(*)
      @hotplug = ""
      Builtins.y2debug("type=%1", @type)
      if Builtins.issubstring(@type, "-")
        @type = Builtins.regexpsub(@type, "([^-]+)-.*$", "\\1")
      end
      Builtins.y2debug("type=%1", @type)

      nil
    end

    PROPOSED_PPPOE_MTU = "1492".freeze # suggested value for PPPoE
    # A default configuration for device when installer needs to configure it
    def ProposeItem(item_id)
      Builtins.y2milestone("Propose configuration for %1", GetDeviceName(item_id))
      return false if Select("") != true

      type = Items().fetch(item_id, {}).fetch("hwinfo", {})[type]
      builder = Y2Network::InterfaceConfigBuilder.for(type)

      builder.mtu = PROPOSED_PPPOE_MTU if Arch.s390 && Builtins.contains(["lcs", "eth"], type)
      builder.ip_address = ""
      builder.subnet_prefix = ""
      builder.boot_protocol = Y2Network::BootProtocol::DHCP

      # see bsc#176804
      devicegraph = Y2Storage::StorageManager.instance.staging
      if devicegraph.filesystem_in_network?("/")
        builder.startmode = "nfsroot"
        Builtins.y2milestone("startmode nfsroot")
      end

      # FIXME: seems like a hack
      NetworkInterfaces.Add
      @operation = :edit
      Ops.set(
        @Items,
        [item_id, "ifcfg"],
        Ops.get_string(GetLanItem(item_id), ["hwinfo", "dev_name"], "")
      )
      # FIXME: is it needed?
      @description = HardwareName(
        [Ops.get_map(GetLanItem(item_id), "hwinfo", {})],
        Ops.get_string(GetLanItem(item_id), ["hwinfo", "dev_name"], "")
      )

      Commit(builder)
      Builtins.y2milestone("After configuration propose %1", GetLanItem(item_id))
      true
    end

    def setDriver(driver)
      Builtins.y2milestone(
        "driver %1, %2",
        driver,
        Ops.get_string(getCurrentItem, ["hwinfo", "module"], "")
      )
      if Ops.get_string(getCurrentItem, ["hwinfo", "module"], "") == driver &&
          IsEmpty(Ops.get_string(getCurrentItem, ["udev", "driver"], ""))
        return
      end
      Ops.set(@Items, [@current, "udev", "driver"], driver)

      nil
    end

    def enableCurrentEditButton
      return true if needFirmwareCurrentItem
      return true if Arch.s390
      if IsEmpty(Ops.get_string(getCurrentItem, ["hwinfo", "dev_name"], "")) &&
          Ops.greater_than(
            Builtins.size(Ops.get_map(getCurrentItem, "hwinfo", {})),
            0
          )
        return false
      else
        return true
      end
    end

    # Creates eth emulation for s390 devices
    #
    # @param dev_attrs [Hash] an s390 device description (e.g. as obtained from AY profile).
    # If it contains s390 device attributes definition, then these definitions takes
    # precendence over values assigned to corresponding LanItems' global variables
    # before the method invocation. Hash keys are strings named after LanItems'
    # s390 globals.
    def createS390Device(dev_attrs = {})
      Builtins.y2milestone("creating device s390 network device, #{dev_attrs}")

      # FIXME: leftover from dropping LanUdevAuto module. This was its way how to
      # configure s390 specific globals. When running in "normal" mode these attributes
      # are initialized elsewhere (see S390Dialog in include/network/lan/hardware.rb)
      if !dev_attrs.empty?
        Select("")
        @type = dev_attrs["type"] || ""
        @qeth_chanids = dev_attrs["chanids"] || ""
        @qeth_layer2 = dev_attrs.fetch("layer2", false)
        @qeth_portname = dev_attrs["portname"] || ""
        @chan_mode = dev_attrs["protocol"] || ""
        @iucv_user = dev_attrs["router"] || ""
      end

      result = true
      # command to create device
      command1 = ""
      # command to find created device
      command2 = ""
      case @type
      when "hsi", "qeth"
        @portnumber_param = if Ops.greater_than(Builtins.size(@qeth_portnumber), 0)
          Builtins.sformat("-n %1", @qeth_portnumber.to_s.shellescape)
        else
          ""
        end
        @portname_param = if Ops.greater_than(Builtins.size(@qeth_portname), 0)
          Builtins.sformat("-p %1", @qeth_portname.shellescape)
        else
          ""
        end
        @options_param = if Ops.greater_than(Builtins.size(@qeth_options), 0)
          Builtins.sformat("-o %1", @qeth_options.shellescape)
        else
          ""
        end
        command1 = Builtins.sformat(
          "/sbin/qeth_configure %1 %2 %3 %4 %5 1",
          @options_param,
          @qeth_layer2 ? "-l" : "",
          @portname_param,
          @portnumber_param,
          @qeth_chanids
        )
        command2 = Builtins.sformat(
          "/usr/bin/ls /sys/devices/qeth/%1/net/ | /usr/bin/head -n1 | /usr/bin/tr -d '\n'",
          Ops.get(Builtins.splitstring(@qeth_chanids, " "), 0, "")
        )
      when "ctc"
        # chan_ids (read, write), protocol
        command1 = Builtins.sformat(
          "/sbin/ctc_configure %1 1 %2",
          @qeth_chanids,
          @chan_mode.shellescape
        )
        command2 = Builtins.sformat(
          "/usr/bin/ls /sys/devices/ctcm/%1/net/ | /usr/bin/head -n1 | /usr/bin/tr -d '\n'",
          Ops.get(Builtins.splitstring(@qeth_chanids, " "), 0, "").shellescape
        )
      when "lcs"
        # chan_ids (read, write), protocol
        command1 = Builtins.sformat(
          "/sbin/ctc_configure %1 1 %2",
          @qeth_chanids,
          @chan_mode.shellescape
        )
        command2 = Builtins.sformat(
          "/usr/bin/ls /sys/devices/lcs/%1/net/ | /usr/bin/head -n1 | /usr/bin/tr -d '\n'",
          Ops.get(Builtins.splitstring(@qeth_chanids, " "), 0, "").shellescape
        )
      when "iucv"
        # router
        command1 = Builtins.sformat("/sbin/iucv_configure %1 1", @iucv_user.shellescape)
        command2 = Builtins.sformat(
          "/usr/bin/ls /sys/devices/%1/*/net/ | /usr/bin/head -n1 | /usr/bin/tr -d '\n'",
          @type.shellescape
        )
      else
        Builtins.y2error("Unsupported type : %1", @type)
      end
      Builtins.y2milestone("execute %1", command1)
      output1 = SCR.Execute(path(".target.bash_output"), command1)
      if Ops.get_integer(output1, "exit", -1) == 0 &&
          Builtins.size(Ops.get_string(output1, "stderr", "")) == 0
        Builtins.y2milestone("Success : %1", output1)
      else
        Builtins.y2error("Problem occured : %1", output1)
        result = false
      end
      Builtins.y2milestone("output1 %1", output1)

      if result
        Builtins.y2milestone("command2 %1", command2)
        output2 = Convert.convert(
          SCR.Execute(path(".target.bash_output"), command2),
          from: "any",
          to:   "map <string, any>"
        )
        Builtins.y2milestone("output2 %1", output2)
        if Ops.get_integer(output2, "exit", -1) == 0 &&
            Builtins.size(Ops.get_string(output2, "stderr", "")) == 0
          Ops.set(
            @Items,
            [@current, "ifcfg"],
            Ops.get_string(output2, "stdout", "")
          )
          Ops.set(
            @Items,
            [@current, "hwinfo", "dev_name"],
            Ops.get_string(output2, "stdout", "")
          )
          Builtins.y2milestone(
            "Device %1 created",
            Ops.get_string(output2, "stdout", "")
          )
        else
          Builtins.y2error("Some problem occured : %1", output2)
          result = false
        end
      end

      result
    end

    #  Creates a list of udev rules for old style named interfaces
    #
    #  It takes a whole "interfaces" section of AY profile and produces
    #  a list of udev rules to guarantee device naming persistency.
    #  The rule is base on attributes described in old style name
    #
    #  @param [Array] list of hashes describing interfaces in AY profile
    #  @return [Array] list of hashes for udev rules
    def createUdevFromIfaceName(interfaces)
      return [] if !interfaces || interfaces.empty?

      udev_rules = []
      attr_map = {
        "id"  => "ATTR{address}",
        "bus" => "KERNELS"
      }

      # rubocop:disable Next
      # the check is disabled bcs the code uses capture groups. Rewriting
      # the code would require some tricks to access these groups
      interfaces.each do |interface|
        if /.*-(?<attr>id|bus)-(?<value>.*)/ =~ interface["device"]
          udev_rules << {
            "rule"  => attr_map[attr],
            "value" => value,
            "name"  => getDeviceName(interface["device"])
          }
        end
      end
      # rubocop:enable Next

      log.info("converted interfaces: #{interfaces}")

      udev_rules
    end

    # Configures available devices for obtaining hostname via specified device
    #
    # This is related to setting system's hostname via DHCP. Apart of global
    # DHCLIENT_SET_HOSTNAME which is set in /etc/sysconfig/network/dhcp and is
    # used as default, one can specify the option even per interface. To avoid
    # collisions / undeterministic behavior the system should be configured so,
    # that just one DHCP interface can update the hostname. E.g. global option
    # can be set to "no" and just only one ifcfg can have the option set to "yes".
    #
    # @param [String] device name where should be hostname configuration active
    # @return [Boolean] false when the configuration cannot be set for a device
    def conf_set_hostname(device)
      return false if !find_dhcp_ifaces.include?(device)

      clear_set_hostname

      ret = SetItemSysconfigOpt(find_configured(device), "DHCLIENT_SET_HOSTNAME", "yes")

      SetModified()

      ret
    end

    # Removes DHCLIENT_SET_HOSTNAME from all ifcfgs
    #
    # @return [Array<String>] list of names of cleared devices
    def clear_set_hostname
      log.info("Clearing DHCLIENT_SET_HOSTNAME flag from device configs")

      ret = []

      GetNetcardInterfaces().each do |item_id|
        dev_map = GetDeviceMap(item_id)
        next if dev_map.nil? || dev_map.empty?
        next if !dev_map["DHCLIENT_SET_HOSTNAME"]

        dev_map["DHCLIENT_SET_HOSTNAME"] = nil

        SetDeviceMap(item_id, dev_map)
        SetModified()

        ret << GetDeviceName(item_id)
      end

      log.info("#{ret.inspect} use default DHCLIENT_SET_HOSTNAME")

      ret
    end

    # Returns unused name for device of given type
    #
    # When already having eth0, eth1, enp0s3 devices (eth type) and asks for new
    # device of eth type it will e.g. return eth2 as a free name.
    #
    # Method always returns name in the oldfashioned schema (eth0, br1, ...)
    #
    # @raise [ArgumentError] when type is nil or empty
    # @param type [String] device type
    # @return [String] available device name
    def new_type_device(type)
      new_type_devices(type, 1).first
    end

    # Returns a list of unused names for devices of given type
    #
    # Also @see new_type_device
    #
    # @raise [ArgumentError] when type is nil or empty
    # @param type [String] device type
    # @param count [Integer] requested count of names
    # @return [Array<String>] list of free names, empty if count is < 1
    def new_type_devices(type, count)
      raise ArgumentError, "Valid device type expected" if type.nil? || type.empty?
      return [] if count < 1

      known_devs = find_type_ifaces(type)

      candidates = (0..known_devs.size + count - 1).map { |c| "#{type}#{c}" }

      (candidates - known_devs)[0..count - 1]
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

    # Returns a formated string with the interfaces that are part of a bridge
    # or of a bond interface.
    #
    # @param [String] ifcfg_type
    # @param [String] ifcfg_name
    # @return [String] formated string with the interface type and the interfaces enslaved
    def slaves_desc(ifcfg_type, ifcfg_name)
      if ifcfg_type == "bond"
        slaves = Y2Network::Config.find(:yast).interfaces.bond_slaves(ifcfg_name)
        desc = _("Bonding slaves")
      else
        slaves = Y2Network::Config.find(:yast).interfaces.bridge_slaves(ifcfg_name)
        desc = _("Bridge Ports")
      end

      format("%s: %s", desc, slaves.join(" "))
    end

    # Check if the given interface is enslaved in a bond or in a bridge
    #
    # @return [Boolean] true if enslaved
    def enslaved?(ifcfg_name)
      bond_index = Y2Network::Config.find(:yast).interfaces.bond_index
      bridge_index = Y2Network::Config.find(:yast).interfaces.bridge_index

      return true if bond_index[ifcfg_name] || bridge_index[ifcfg_name]

      false
    end

    # Return the current name of the {LanItems} given
    #
    # @param item_id [Integer] a key for {#Items}
    def current_name_for(item_id)
      renamed?(item_id) ? renamed_to(item_id) : GetDeviceName(item_id)
    end

    # Finds a LanItem which name is in collision to the provided name
    #
    # @param name [String] a device name (eth0, ...)
    # @return [Integer, nil] item id (see LanItems::Items)
    def colliding_item(name)
      item_id, _item_map = Items().find { |i, _| name == current_name_for(i) }
      item_id
    end

    # Return wether the routing devices list needs to be updated or not to include
    # the current interface name
    #
    # @return [Boolean] false if the current interface name is already present
    def update_routing_devices?
      device_names = yast_config.interfaces.map(&:name)
      !device_names.include?(current_name)
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
      return unless config && config.routing
      routing = config.routing
      add_device_to_routing(to)
      target_interface = config.interfaces.by_name(to)
      return unless target_interface
      routing.routes.select { |r| r.interface && r.interface.name == from }
             .each { |r| r.interface = target_interface }
    end

    # Renames an interface
    #
    # @todo This method exists just to keep some compatibility during
    #       the migration to network-ng.

    # @param old_name [String] Old device name
    def rename_current_device_in_routing(old_name)
      config = yast_config
      return if config.nil?
      interface = config.interfaces.by_name(old_name)
      return unless interface
      interface.name = current_name
    end

    # Removes the interface with the given name
    #
    # @todo This method exists just to keep some compatibility during
    #       the migration to network-ng.
    # @todo It does not check orphan routes.
    def remove_current_device_from_routing
      config = yast_config
      return if config.nil?
      name = current_name
      return if name.empty?
      config.interfaces.delete_if { |i| i.name == name }
    end

  private

    # Checks if given lladdr can be written into ifcfg
    #
    # @param lladdr [String] logical link address, usually MAC address in case
    #                        of qeth device
    # @return [true, false] check result
    def s390_correct_lladdr(lladdr)
      return false if !Arch.s390
      return false if lladdr.nil?
      return false if lladdr.empty?
      return false if lladdr.strip == "00:00:00:00:00:00"

      true
    end

    # Removes all records connected to the ip from /etc/hosts
    def drop_hosts(ip)
      log.info("Deleting hostnames assigned to #{ip} from /etc/hosts")
      Host.remove_ip(ip)
    end

    # Exports udev rules for AY profile
    def export_udevs(devices)
      devices = deep_copy(devices)
      ay = { "s390-devices" => {}, "net-udev" => {} }
      if Arch.s390
        devs = []
        Builtins.foreach(
          Convert.convert(devices, from: "map", to: "map <string, any>")
        ) do |_type, value|
          devs = Convert.convert(
            Builtins.union(devs, Map.Keys(Convert.to_map(value))),
            from: "list",
            to:   "list <string>"
          )
        end
        Builtins.foreach(devs) do |device|
          begin
            driver = File.readlink("/sys/class/net/#{device}/device/driver")
          rescue SystemCallError => e
            Builtins.y2error("Failed to read driver #{e.inspect}")
            next
          end
          driver = File.basename(driver)
          device_type = ""
          chanids = ""
          case driver
          when "qeth"
            device_type = driver
          when "ctcm"
            device_type = "ctc"
          when "netiucv"
            device_type = "iucv"
          else
            Builtins.y2error("unknown driver type :#{driver}")
          end
          chan_ids = SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "for i in $(seq 0 2); do chanid=$(/usr/bin/ls -l /sys/class/net/%1/device/cdev$i); /usr/bin/echo ${chanid##*/}; done | /usr/bin/tr '\n' ' '",
              device.shellescape
            )
          )
          if !chan_ids["stdout"].empty?
            chanids = String.CutBlanks(Ops.get_string(chan_ids, "stdout", ""))
          end

          # we already know that kernel device exist, otherwise next above would apply
          # FIXME: It seems that it is not always the case (bsc#1124002)
          portname_file = "/sys/class/net/#{device}/device/portname"
          portname = ::File.exist?(portname_file) ? ::File.read(portname_file).strip : ""

          protocol_file = "/sys/class/net/#{device}/device/protocol"
          protocol = ::File.exist?(protocol_file) ? ::File.read(protocol_file).strip : ""

          layer2_ret = SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "/usr/bin/grep -q 1 /sys/class/net/%1/device/layer2",
              device.shellescape
            )
          )
          layer2 = layer2_ret == 0
          Ops.set(ay, ["s390-devices", device], "type" => device_type)
          Ops.set(ay, ["s390-devices", device, "chanids"], chanids) if !chanids.empty?
          Ops.set(ay, ["s390-devices", device, "portname"], portname) if !portname.empty?
          Ops.set(ay, ["s390-devices", device, "protocol"], protocol) if !protocol.empty?
          Ops.set(ay, ["s390-devices", device, "layer2"], true) if layer2
          port0 = SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "port0=$(/usr/bin/ls -l /sys/class/net/%1/device/cdev0); /usr/bin/echo ${port0##*/} | /usr/bin/tr -d '\n'",
              device
            )
          )
          Builtins.y2milestone("port0 %1", port0)
          if !port0["stdout"].empty?
            value = Ops.get_string(port0, "stdout", "")
            Ops.set(
              ay,
              ["net-udev", device],
              "rule" => "KERNELS", "name" => device, "value" => value
            )
          end
        end
      else
        configured = Items().select { |i, _| IsItemConfigured(i) }
        ay["net-udev"] = configured.keys.each_with_object({}) do |id, udev|
          @current = id # for GetItemUdev

          name = GetItemUdev("NAME").to_s
          rule = ["ATTR{address}", "KERNELS"].find { |r| !GetItemUdev(r).to_s.empty? }

          next if !rule || name.empty?

          udev[name] = {
            "rule"  => rule,
            "name"  => name,
            "value" => GetItemUdev(rule)
          }
        end
      end

      Builtins.y2milestone("AY profile %1", ay)
      deep_copy(ay)
    end

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
    publish_variable :force_restart, "boolean"
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
    publish_variable :bootproto, "string"
    publish_variable :ipaddr, "string"
    publish_variable :netmask, "string"
    publish_variable :set_default_route, "boolean"
    publish_variable :prefix, "string"
    publish_variable :startmode, "string"
    publish_variable :wl_mode, "string"
    publish_variable :wl_essid, "string"
    publish_variable :wl_nwid, "string"
    publish_variable :wl_auth_mode, "string"
    publish_variable :wl_wpa_psk, "string"
    publish_variable :wl_key_length, "string"
    publish_variable :wl_key, "list <string>"
    publish_variable :wl_default_key, "integer"
    publish_variable :wl_nick, "string"
    publish_variable :bond_slaves, "list <string>"
    publish_variable :bond_option, "string"
    publish_variable :vlan_etherdevice, "string"
    publish_variable :bridge_ports, "string"
    publish_variable :wl_wpa_eap, "map <string, any>"
    publish_variable :wl_channel, "string"
    publish_variable :wl_frequency, "string"
    publish_variable :wl_bitrate, "string"
    publish_variable :wl_accesspoint, "string"
    publish_variable :wl_power, "boolean"
    publish_variable :wl_ap_scanmode, "string"
    publish_variable :wl_auth_modes, "list <string>"
    publish_variable :wl_enc_modes, "list <string>"
    publish_variable :wl_channels, "list <string>"
    publish_variable :wl_bitrates, "list <string>"
    publish_variable :qeth_portname, "string"
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
    publish function: :IsCurrentConfigured, type: "boolean ()"
    publish function: :GetDeviceName, type: "string (integer)"
    publish function: :GetCurrentName, type: "string ()"
    publish function: :GetDeviceType, type: "string (integer)"
    publish function: :GetDeviceMap, type: "map <string, any> (integer)"
    publish function: :GetItemUdevRule, type: "list <string> (integer)"
    publish function: :GetItemUdev, type: "string (string)"
    publish function: :ReplaceItemUdev, type: "list <string> (string, string, string)"
    publish function: :WriteUdevRules, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :SetModified, type: "void ()"
    publish function: :AddNew, type: "void ()"
    publish function: :GetItemModules, type: "list <string> (string)"
    publish function: :GetNetcardNames, type: "list <string> ( list <integer>)"
    publish function: :FindAndSelect, type: "boolean (string)"
    publish function: :FindDeviceIndex, type: "integer (string)"
    publish function: :ReadHw, type: "void ()"
    publish function: :Read, type: "void ()"
    publish function: :needFirmwareCurrentItem, type: "boolean ()"
    publish function: :GetFirmwareForCurrentItem, type: "string ()"
    publish function: :GetBondSlaves, type: "list <string> (string)"
    publish function: :BuildLanOverview, type: "list ()"
    publish function: :Overview, type: "list ()"
    publish function: :isCurrentHotplug, type: "boolean ()"
    publish function: :isCurrentDHCP, type: "boolean ()"
    publish function: :GetItemDescription, type: "string ()"
    publish function: :SelectHWMap, type: "void (map)"
    publish function: :SetDeviceVars, type: "void (map, map)"
    publish function: :Select, type: "boolean (string)"
    publish function: :Commit, type: "boolean ()"
    publish function: :Rollback, type: "boolean ()"
    publish function: :DeleteItem, type: "void ()"
    publish function: :ProposeItem, type: "boolean ()"
    publish function: :setDriver, type: "void (string)"
    publish function: :enableCurrentEditButton, type: "boolean ()"
    publish function: :createS390Device, type: "boolean ()"
    publish function: :find_dhcp_ifaces, type: "list <string> ()"
  end

  LanItems = LanItemsClass.new
  LanItems.main
end
