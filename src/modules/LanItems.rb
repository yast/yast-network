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
require "network/install_inf_convertor"

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
  # rubocop:disable ClassLength
  class LanItemsClass < Module
    attr_reader :ipoib_modes
    attr_accessor :ipoib_mode

    include Logger

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "NetworkInterfaces"
      Yast.import "ProductFeatures"
      Yast.import "NetworkConfig"
      Yast.import "NetworkStorage"
      Yast.import "Host"
      Yast.import "Storage"
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
      # FIXME: always empty string - remove all occuriences
      @alias = ""
      @current = -1
      @hotplug = ""

      @Requires = []

      # address options
      # boot protocol: BOOTPROTO
      @bootproto = "static"
      @ipaddr = ""
      @remoteip = ""
      @netmask = ""
      @prefix = ""

      @startmode = "auto"
      @ifplugd_priority = "0"
      @mtu = ""
      @ethtool_options = ""

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

      # bond options
      @bond_slaves = []
      @bond_option = ""

      @MAX_BOND_SLAVE = 10

      # VLAN option
      @vlan_etherdevice = ""
      @vlan_id = ""

      # interfaces attached to bridge (list delimited by ' ')
      @bridge_ports = ""
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

      # infiniband options
      @ipoib_mode = ""
      @ipoib_modes = {
        # translators: a possible value for: IPoIB device mode
        "connected" => _("connected"),
        "datagram"  => _("datagram")
      }

      # propose options
      @proposal_valid = false

      # NetworkModules:: name
      @nm_name = ""

      Yast.include self, "network/hardware.rb"

      # Default values used when creating an emulated NIC for physical s390 hardware.
      @s390_defaults = YAML.load_file(Directory.find_data_file("network/s390_defaults.yml")) if Arch.s390

      # the defaults here are what sysconfig defaults to
      # (as opposed to what a new interface gets, in {#Select)}
      @SysconfigDefaults = YAML.load_file(Directory.find_data_file("network/sysconfig_defaults.yml"))

      # this is the map of kernel modules vs. requested firmware
      # non-empty keys are firmware packages shipped by SUSE
      @request_firmware = YAML.load_file(Directory.find_data_file("network/firmwares.yml"))
    end

    # Returns configuration of item (see LanItems::Items) with given id.
    #
    # @param itemId [Integer] a key for {#Items}
    def GetLanItem(itemId)
      Ops.get_map(@Items, itemId, {})
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

      devname = GetDeviceName(itemId)
      devtype = NetworkInterfaces.GetType(devname)

      Convert.convert(
        Ops.get(NetworkInterfaces.FilterDevices("netcard"), [devtype, devname]),
        from: "any",
        to:   "map <string, any>"
      )
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
          Ops.get_string(getCurrentItem, ["hwinfo", "mac"], "")
        )
        Builtins.y2milestone(
          "No Udev rules found, creating default: %1",
          udev_rules
        )
      end

      deep_copy(udev_rules)
    end

    def GetItemUdev(key)
      value = ""

      Builtins.foreach(getUdevFallback) do |row|
        if Builtins.issubstring(row, key)
          items = Builtins.filter(Builtins.splitstring(row, "=")) do |s|
            Ops.greater_than(Builtins.size(s), 0)
          end
          if Builtins.size(items) == 2 && Ops.get_string(items, 0, "") == key
            value = Builtins.deletechars(Ops.get_string(items, 1, ""), "\"")
          else
            Builtins.y2warning(
              "udev items %1 doesn't match the key %2",
              items,
              key
            )
          end
        end
      end
      value
    end

    def ReplaceItemUdev(replace_key, new_key, new_val)
      new_rules = []
      # udev syntax distinguishes among others:
      # =    for assignment
      # ==   for equality checks
      operator = new_key == "NAME" ? "=" : "=="

      Builtins.foreach(getUdevFallback) do |row|
        if Builtins.issubstring(row, replace_key)
          row = Builtins.sformat("%1%2\"%3\"", new_key, operator, new_val)
        end
        new_rules = Builtins.add(new_rules, row)
      end

      Builtins.y2debug(
        "LanItems::ReplaceItemUdev: udev rules %1",
        Ops.get_list(@Items, [@current, "udev", "net"], [])
      )

      Ops.set(@Items, [@current, "udev", "net"], new_rules)

      Builtins.y2debug(
        "LanItems::ReplaceItemUdev(%1, %2, %3) %4",
        replace_key,
        new_key,
        new_val,
        new_rules
      )

      deep_copy(new_rules)
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
      if (GetCurrentName() != name)
        @Items[@current]["renamed_to"] = name
      else
        @Items[@current].delete("renamed_to")
      end
    end

    # Returns new name for current item
    #
    # @param item_id [Integer] a key for {#Items}
    def renamed_to(item_id)
      @Items[item_id]["renamed_to"]
    end

    def current_renamed_to
      renamed_to(@current)
    end

    # Tells if current item was renamed
    #
    # @param item_id [Integer] a key for {#Items}
    def renamed?(item_id)
      return false if !LanItems.Items[item_id].key?("renamed_to")
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
          SetLinkDown(dev_name) if !Mode.autoinst

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
      SCR.Execute(path(".target.bash"), "udevadm settle")
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

      # FIXME: hack: no "netcard" filter as biosdevname names it diferently (bnc#712232)
      NetworkInterfaces.Write("")
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
      @Items[@current] = { "commited" => false }
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

    # Searches map of known devices and decides if referenced lan item
    # can be enslaved in a bond device
    #
    # @param [String] bondMaster    name of master device
    # @param [Fixnum] itemId        index into LanItems::Items
    # TODO: Check for valid configurations. E.g. bond device over vlan
    # is nonsense and is not supported by netconfig.
    # Also devices enslaved in a bridge should be excluded too.
    def IsBondable(bondMaster, itemId)
      ret = true
      devname = GetDeviceName(itemId)
      bonded = BuildBondIndex()

      # check if the device is L2 capable
      if Arch.s390
        s390_config = s390_ReadQethConfig(devname)

        # only devices with L2 support can be enslaved in bond. See bnc#719881
        ret &&= s390_config["QETH_LAYER2"] == "yes"
      end

      ifcfg = GetDeviceMap(itemId)

      itemBondMaster = bonded[devname] || ""

      if !itemBondMaster.empty? && bondMaster != itemBondMaster
        log.debug("IsBondable: excluding lan item (#{itemId}: #{devname}) for #{GetCurrentName()} - is already bonded")
        return false
      end

      return ret if ifcfg.nil?

      # filter the eth devices (BOOTPROTO=none)
      # don't care about STARTMODE (see bnc#652987c6)
      ret &&= ifcfg["BOOTPROTO"] == "none"

      ret
    end

    # Decides if given lan item can be enslaved in a bridge.
    #
    # @param [String] bridgeMaster  name of master device
    # @param [Fixnum] itemId        index into LanItems::Items
    # TODO: bridgeMaster is not used yet bcs detection of bridge master
    # for checked device is missing.
    def IsBridgeable(_bridgeMaster, itemId)
      ifcfg = GetDeviceMap(itemId)

      # no netconfig configuration has been found so nothing
      # blocks using the device as bridge slave
      return true if ifcfg.nil?

      devname = GetDeviceName(itemId)
      bonded = BuildBondIndex()

      if bonded[devname]
        log.debug("Excluding lan item (#{itemId}: #{devname}) - is bonded")
        return false
      end

      devtype = GetDeviceType(itemId)

      # exclude forbidden configurations
      case devtype
      when "br"
        log.debug("Excluding lan item (#{itemId}: #{devname}) - is bridge")
        return false

      when "tun"
        log.debug("Excluding lan item (#{itemId}: #{devname}) - is tun")
        return false
      end

      case ifcfg["STARTMODE"]
      when "nfsroot"
        log.debug("Excluding lan item (#{itemId}: #{devname}) - is nfsroot")
        return false

      when "ifplugd"
        log.debug("Excluding lan item (#{itemId}: #{devname}) - ifplugd")
        return false

      else
        return true
      end
    end

    # Iterates over all items and lists those for which given validator returns
    # true.
    #
    # @param [boolean (string, integer)] validator   a reference to function which checks if an interface
    #                      can be enslaved. Validator takes one argument - itemId.
    # @return  [Array] of lan item ids (see LanItems::Items)
    def GetSlaveCandidates(master, validator)
      validator = deep_copy(validator)
      if validator.nil?
        Builtins.y2error("GetSlaveCandidates: needs a validator.")
        return []
      end
      if IsEmpty(master)
        Builtins.y2error("GetSlaveCandidates: master device name is required.")
        return []
      end

      result = []

      Builtins.foreach(@Items) do |itemId, _attribs|
        if @current != itemId && validator.call(master, itemId)
          result = Builtins.add(result, itemId)
        else
          Builtins.y2debug(
            "GetSlaveCandidates: validation failed for item (%1), current (%2)",
            itemId,
            @current
          )
        end
      end

      Builtins.y2milestone(
        "GetSlaveCandidates: candidates for enslaving: %1",
        result
      )

      deep_copy(result)
    end

    # Creates list of items (interfaces) which can be used as
    # a bond slave.
    #
    # @param [String] bondMaster    bond device name
    def GetBondableInterfaces(bondMaster)
      GetSlaveCandidates(
        bondMaster,
        fun_ref(method(:IsBondable), "boolean (string, integer)")
      )
    end

    # Creates list of items (interfaces) which can be used as
    # a bridge slave.
    #
    # @param [String] bridgeMaster  bridge device name
    def GetBridgeableInterfaces(bridgeMaster)
      GetSlaveCandidates(
        bridgeMaster,
        fun_ref(method(:IsBridgeable), "boolean (string, integer)")
      )
    end

    # Creates list of all known netcard items
    #
    # It means list of item ids of all netcards which are detected and/or
    # configured in the system
    def GetNetcardInterfaces
      @Items.keys
    end

    # Creates list of names of all known netcards configured even unconfigured
    def GetNetcardNames
      GetDeviceNames(GetNetcardInterfaces())
    end

    # get list of all configurations for "netcard" macro in NetworkInterfaces module
    def getNetworkInterfaces
      configurations = NetworkInterfaces.FilterDevices("netcard")
      devtypes = NetworkInterfaces.CardRegex["netcard"].to_s.split("|")

      devtypes.inject([]) do |acc, type|
        conf = configurations[type].to_h
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
    # @returns [String] new style name in case of success. Given name otherwise.
    def getDeviceName(oldname)
      newname = oldname

      hardware = ReadHardware("netcard")

      hardware.each do |hw|
        hw_dev_name = hw["dev_name"] || ""
        hw_dev_mac = hw["mac"] || ""
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
      ReadHw()
      NetworkInterfaces.Read
      NetworkInterfaces.CleanHotplugSymlink

      interfaces = getNetworkInterfaces
      # match configurations to Items list with hwinfo
      Builtins.foreach(interfaces) do |confname|
        pos = nil
        val = {}
        Builtins.foreach(
          Convert.convert(
            @Items,
            from: "map <integer, any>",
            to:   "map <integer, map <string, any>>"
          )
        ) do |key, value|
          if Ops.get_string(value, ["hwinfo", "dev_name"], "") == confname
            pos = key
            val = deep_copy(value)
          end
        end
        if pos.nil?
          pos = Builtins.size(@Items)
          Ops.set(@Items, pos, {})
        end
        Ops.set(@Items, [pos, "ifcfg"], confname)
      end

      # add to Items also virtual devices (configurations) without hwinfo
      Builtins.foreach(interfaces) do |confname|
        already = false
        Builtins.foreach(
          Convert.convert(
            Map.Keys(@Items),
            from: "list",
            to:   "list <integer>"
          )
        ) do |key|
          if confname == Ops.get_string(@Items, [key, "ifcfg"], "")
            already = true
            raise Break
          end
        end
        if !already
          AddNew()
          Ops.set(@Items, @current, "ifcfg" => confname)
        end
      end
      Builtins.y2milestone("Read Configuration LanItems::Items %1", @Items)

      nil
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
    # @param [Hash] AY profile converted into hash
    # @return [Boolean] on success
    def Import(settings)
      reset_cache

      NetworkInterfaces.Import("netcard", settings["devices"] || {})
      NetworkInterfaces.List("netcard").each do |device|
        AddNew()
        LanItems.Items[current] = { "ifcfg" => device }
      end

      autoinstall_settings["start_immediately"] = settings.fetch("start_immediately", false)
      autoinstall_settings["strict_IP_check_timeout"] = settings.fetch("strict_IP_check_timeout", -1)
      autoinstall_settings["keep_install_network"] = settings.fetch("keep_install_network", false)

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

    # Creates list of devices enslaved in any bond device.
    def GetBondSlaves(bond_master)
      slaves = []
      slave_index = 0

      while Ops.less_than(slave_index, @MAX_BOND_SLAVE)
        slave = Ops.get_string(
          NetworkInterfaces.FilterDevices("netcard"),
          [
            "bond",
            bond_master,
            Builtins.sformat("BONDING_SLAVE%1", slave_index)
          ],
          ""
        )

        if Ops.greater_than(Builtins.size(slave), 0)
          slaves = Builtins.add(slaves, slave)
        end

        slave_index = Ops.add(slave_index, 1)
      end

      deep_copy(slaves)
    end

    def BuildBondIndex
      index = {}
      bond_devs = Convert.convert(
        Ops.get(NetworkInterfaces.FilterDevices("netcard"), "bond", {}),
        from: "map",
        to:   "map <string, map>"
      )

      Builtins.foreach(bond_devs) do |bond_master, _value|
        Builtins.foreach(GetBondSlaves(bond_master)) do |slave|
          index = Builtins.add(index, slave, bond_master)
        end
      end

      Builtins.y2debug("bond slaves index: %1", index)

      deep_copy(index)
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

    def ip_overview(ip)
      bullets = []

      case ip
      when "NONE", ""
      # do nothing
      when /DHCP/
        bullets << format("%s %s", _("IP address assigned using"), ip)
      else
        prefixlen = NetworkInterfaces.Current["PREFIXLEN"]
        if prefixlen
          bullets << format(_("IP address: %s/%s"), ip, prefixlen)
        else
          subnetmask = NetworkInterfaces.Current["NETMASK"]
          bullets << format(_("IP address: %s, subnet mask %s"), ip, subnetmask)
        end
      end

      # build aliases overview
      item_aliases = NetworkInterfaces.Current["_aliases"] || {}
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
        ip = _("Not configured")

        item_hwinfo = LanItems.Items[key]["hwinfo"] || {}
        descr = item_hwinfo["name"] || ""

        note = ""
        bullets = []
        ifcfg_name = LanItems.Items[key]["ifcfg"] || ""

        LanItems.type = NetworkInterfaces.GetType(ifcfg_name)
        if !ifcfg_name.empty?
          ifcfg_conf = GetDeviceMap(key)
          ifcfg_desc = ifcfg_conf["NAME"]
          descr = ifcfg_desc if !ifcfg_desc.nil? && !ifcfg_desc.empty?
          descr = CheckEmptyName(LanItems.type, descr)
          ip = DeviceProtocol(ifcfg_conf)
          status = DeviceStatus(
            LanItems.type,
            ifcfg_name,
            ifcfg_conf
          )

          bullets << _("Device Name: %s") % ifcfg_name
          bullets += startmode_overview(key)
          bullets += ip_overview(ip) if ifcfg_conf["STARTMODE"] != "managed"

          if LanItems.type == "wlan" &&
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

          if LanItems.type == "bond"
            bond_slaves_desc = format(
              "%s: %s",
              _("Bonding slaves"),
              GetBondSlaves(ifcfg_name).join(" ")
            )
            bullets << bond_slaves_desc
          end

          bond_index = BuildBondIndex()
          bond_master = Ops.get(
            bond_index,
            ifcfg_name,
            ""
          )

          if !bond_master.empty?
            note = format(_("enslaved in %s"), bond_master)
            bond_master_desc = format("%s: %s", _("Bonding master"), bond_master)
            bullets << bond_master_desc
          end

          if renamed?(key)
            note = format("%s -> %s", GetDeviceName(key), renamed_to(key))
          end

          overview << Summary.Device(descr, status)
        else
          descr = CheckEmptyName(LanItems.type, descr)
          overview << Summary.Device(descr, Summary.NotConfigured)
        end
        conn = ""
        conn = HTML.Bold(format("(%s)", _("Not connected"))) if !item_hwinfo["link"]
        conn = HTML.Bold(format("(%s)", _("No hwinfo"))) if item_hwinfo.empty?

        mac_dev = HTML.Bold("MAC : ") + item_hwinfo["mac"].to_s + "<br>"
        bus_id  = HTML.Bold("BusID : ") + item_hwinfo["busid"].to_s + "<br>"

        rich << " " << conn << "<br>" << mac_dev if IsNotEmpty(item_hwinfo["mac"])
        rich << bus_id if IsNotEmpty(item_hwinfo["busid"])
        # display it only if we need it, don't duplicate "ifcfg_name" above
        if IsNotEmpty(item_hwinfo["dev_name"]) && ifcfg_name.empty?
          dev_name = _("Device Name: %s") %  item_hwinfo["dev_name"]
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
          "table_descr" => [descr, ip, ifcfg_name, note]
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
      if hotplugtype == "usb" || hotplugtype == "pcmci"
        return true
      else
        return false
      end
    end

    # Check if currently edited device gets its IP address
    # from DHCP (v4, v6 or both)
    # @return true if it is
    def isCurrentDHCP
      Builtins.regexpmatch(@bootproto, "dhcp[46]?")
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
        if DriverType(@type) == "ctc" || DriverType(@type) == "lcs"
          @qeth_chanids = Builtins.sformat("%1%2 %1%3", devstr, devid0, devid1)
        else
          @qeth_chanids = Builtins.sformat(
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

    # Select the hardware component
    # @param [Fixnum] which index of the component

    def SelectHW(which)
      SelectHWMap(FindHardware(@Hardware, which))

      nil
    end

    #-------------------
    # PRIVATE FUNCTIONS

    # Return 10 free devices
    # @param [String] type device type
    # @return [Array] of 10 free devices
    def FreeDevices(type)
      NetworkInterfaces.GetFreeDevices(type, 10)
    end

    # must be in sync with {#GetDefaultsForHW}
    def SetDefaultsForHW
      Builtins.y2milestone("SetDefaultsForHW type %1", @type)
      @mtu = "1492" if Arch.s390 && Builtins.contains(["lcs", "eth"], @type)

      nil
    end

    # Distributes an ifcfg hash to individual attributes.
    # @param devmap   [Hash] an ifcfg, values are strings
    # @param defaults [Hash] should provide defaults for devmap
    # @return [void]
    def SetDeviceVars(devmap, defaults)
      d = defaults.merge(devmap)
      # address options
      @bootproto         = d["BOOTPROTO"]
      @ipaddr            = d["IPADDR"]
      @prefix            = d["PREFIXLEN"]
      @remoteip          = d["REMOTE_IPADDR"]
      @netmask           = d["NETMASK"]
      @set_default_route = case d["DHCLIENT_SET_DEFAULT_ROUTE"]
                           when "yes" then true
                           when "no" then  false
                             # all other values! count as unspecified which is default value
                           end

      @mtu               = d["MTU"]
      @ethtool_options   = d["ETHTOOL_OPTIONS"]
      @startmode         = d["STARTMODE"]
      @ifplugd_priority  = d["IFPLUGD_PRIORITY"]
      @description       = d["NAME"]
      @bond_option       = d["BONDING_MODULE_OPTS"]
      @vlan_etherdevice  = d["ETHERDEVICE"]
      # FIXME, remember that it can be implied from the name. probably
      @vlan_id           = d["VLAN_ID"]

      @bridge_ports = d["BRIDGE_PORTS"]

      @bond_slaves = []
      Builtins.foreach(devmap) do |key, value|
        if Builtins.regexpmatch(Convert.to_string(key), "BONDING_SLAVE[0-9]+")
          if !Convert.to_string(value).nil?
            @bond_slaves = Builtins.add(@bond_slaves, Convert.to_string(value))
          end
        end
      end

      # tun/tap settings
      @tunnel_set_owner = d["TUNNEL_SET_OWNER"]
      @tunnel_set_group = d["TUNNEL_SET_GROUP"]

      # wireless options
      @wl_mode            = d["WIRELESS_MODE"]
      @wl_essid           = d["WIRELESS_ESSID"]
      @wl_nwid            = d["WIRELESS_NWID"]
      @wl_auth_mode       = d["WIRELESS_AUTH_MODE"]
      @wl_wpa_psk         = d["WIRELESS_WPA_PSK"]
      @wl_key_length      = d["WIRELESS_KEY_LENGTH"]
      @wl_key             = [
        d["WIRELESS_KEY_0"],
        d["WIRELESS_KEY_1"],
        d["WIRELESS_KEY_2"],
        d["WIRELESS_KEY_3"]
      ]
      @wl_key[0]          = d["WIRELESS_KEY"] if (@wl_key[0] || "").empty?

      @wl_default_key     = d["WIRELESS_DEFAULT_KEY"].to_i
      @wl_nick            = d["WIRELESS_NICK"]
      @wl_wpa_eap = {
        "WPA_EAP_MODE"                => d["WIRELESS_EAP_MODE"],
        "WPA_EAP_IDENTITY"            => d["WIRELESS_WPA_IDENTITY"],
        "WPA_EAP_PASSWORD"            => d["WIRELESS_WPA_PASSWORD"],
        "WPA_EAP_ANONID"              => d["WIRELESS_WPA_ANONID"],
        "WPA_EAP_CLIENT_CERT"         => d["WIRELESS_CLIENT_CERT"],
        "WPA_EAP_CLIENT_KEY"          => d["WIRELESS_CLIENT_KEY"],
        "WPA_EAP_CLIENT_KEY_PASSWORD" => d["WIRELESS_CLIENT_KEY_PASSWORD"],
        "WPA_EAP_CA_CERT"             => d["WIRELESS_CA_CERT"],
        "WPA_EAP_AUTH"                => d["WIRELESS_EAP_AUTH"],
        "WPA_EAP_PEAP_VERSION"        => d["WIRELESS_PEAP_VERSION"]
      }
      @wl_channel     = d["WIRELESS_CHANNEL"]
      @wl_frequency   = d["WIRELESS_FREQUENCY"]
      @wl_bitrate     = d["WIRELESS_BITRATE"]
      @wl_accesspoint = d["WIRELESS_AP"]
      @wl_power       = d["WIRELESS_POWER"] == "yes"
      @wl_ap_scanmode = d["WIRELESS_AP_SCANMODE"]

      @ipoib_mode = d["IPOIB_MODE"]

      @aliases = Ops.get_map(devmap, "_aliases", {})

      nil
    end

    # Initializes s390 specific device variables.
    #
    # @param [Hash] devmap    map with s390 specific attributes and its values
    # @param [Hash] defaults  map with default values for attributes not found in devmap
    def SetS390Vars(devmap, defaults)
      return if !Arch.s390
      d = defaults.merge(devmap)

      @qeth_portname   = d["QETH_PORTNAME"]
      @qeth_portnumber = d["QETH_PORTNUMBER"]
      @qeth_layer2     = d["QETH_LAYER2"] == "yes"
      @qeth_chanids    = d["QETH_CHANIDS"]

      # s/390 options
      # We always have to set the MAC Address for qeth Layer2 support.
      # It is used mainly as a hint for user that MAC is expected in case
      # of Layer2 devices. Other devices do not need it. Simply
      # because such devices do not emulate Layer2
      @qeth_macaddress = d["LLADDR"] if @qeth_layer2

      # qeth attribute. FIXME: currently not read from system.
      @ipa_takeover = defaults["IPA_TAKEOVER"] == "yes"

      # not device attribute
      @qeth_options = defaults["QETH_OPTIONS"] || ""

      # handle non qeth devices
      @iucv_user = defaults["IUCV_USER"] || ""
      @chan_mode = defaults["CHAN_MODE"] || ""

      nil
    end

    def InitS390VarsByDefaults
      SetS390Vars({}, @s390_defaults)
    end

    def hotplug_usable?
      true unless Ops.get_string(@Items, [@current, "hwinfo", "hotplug"], "").empty?
    end

    def replace_ifplugd?
      return true if !Arch.is_laptop
      return true if NetworkService.is_network_manager
      return true if ["bond", "vlan", "br"].include? type

      false
    end

    # returns default startmode for a new device
    #
    # startmode is returned according product, Arch and current device type
    def new_device_startmode
      product_startmode = ProductFeatures.GetStringFeature(
        "network",
        "startmode"
      )

      Builtins.y2milestone("Startmode by product: #{product_startmode}")

      case product_startmode
      when "ifplugd"
        if replace_ifplugd?
          startmode = hotplug_usable? ? "hotplug" : "auto"
        else
          startmode = product_startmode
        end
      when "auto"
        startmode = "auto"
      else
        startmode = hotplug_usable? ? "hotplug" : "auto"
      end

      Builtins.y2milestone("New device startmode: #{startmode}")

      startmode
    end

    # returns a map with device options for newly created item
    def new_item_default_options
      {
        # bnc#46369
        "NETMASK"                    => NetHwDetection.result["NETMASK"] || "255.255.255.0",
        "STARTMODE"                  => new_device_startmode,
        # bnc#883836 bnc#868187
        "DHCLIENT_SET_DEFAULT_ROUTE" => "no"
      }
    end

    # Select the given device
    # FIXME: currently *dev* is always ""
    # @param [String] dev device to select ("" for new device, default values)
    # @return true if success
    def Select(dev)
      Builtins.y2debug("dev=%1", dev)

      devmap = new_item_default_options

      # FIXME: encapsulate into LanItems.GetItemType ?
      @type = Ops.get_string(@Items, [@current, "hwinfo", "type"], "eth")
      @device = @type + NetworkInterfaces.GetFreeDevice(@type)

      # TODO: instead of udev use hwinfo dev_name
      NetworkInterfaces.Name = GetItemUdev("NAME")
      if Ops.less_than(Builtins.size(@Items), @current)
        Ops.set(@Items, @current, "ifcfg" => NetworkInterfaces.Name)
      else
        Ops.set(@Items, [@current, "ifcfg"], NetworkInterfaces.Name)
      end

      # FIXME: alias: how to prefill new alias?
      @alias = ""

      # general stuff
      @description = BuildDescription(@type, @device, devmap, @Hardware)

      SetDeviceVars(devmap, @SysconfigDefaults)
      InitS390VarsByDefaults()

      @hotplug = ""
      Builtins.y2debug("type=%1", @type)
      if Builtins.issubstring(@type, "-")
        @type = Builtins.regexpsub(@type, "([^-]+)-.*$", "\\1")
      end
      Builtins.y2debug("type=%1", @type)

      true
    end

    TRISTATE_TO_S = { nil => nil, false => "no", true => "yes" }.freeze

    # Sets device map items related to dhclient
    def setup_dhclient_options(devmap)
      if isCurrentDHCP
        devmap["DHCLIENT_SET_DEFAULT_ROUTE"] = TRISTATE_TO_S.fetch(@set_default_route)
      end
      devmap
    end

    # Sets device map items for device when it is not alias
    def setup_basic_device_options(devmap)
      return devmap if !@alias.empty?

      devmap["MTU"] = @mtu
      devmap["ETHTOOL_OPTIONS"] = @ethtool_options
      devmap["STARTMODE"] = @startmode
      devmap["IFPLUGD_PRIORITY"] = @ifplugd_priority.to_i if @startmode == "ifplugd"
      devmap["BOOTPROTO"] = @bootproto
      devmap["_aliases"] = @aliases

      log.info("aliases #{@aliases}")

      devmap
    end

    # Commit pending operation
    # @return true if success
    def Commit
      if @operation != :add && @operation != :edit
        log.error("Unknown operation: #{@operation}")
        raise ArgumentError, "Unknown operation: #{@operation}"
      end

      newdev = {}

      # #104494 - always write IPADDR+NETMASK, even empty
      newdev["IPADDR"] = @ipaddr
      if !@prefix.empty?
        newdev["PREFIXLEN"] = @prefix
      else
        newdev["NETMASK"] = @netmask
      end
      # #50955 omit computable fields
      newdev["BROADCAST"] = ""
      newdev["NETWORK"] = ""

      newdev["REMOTE_IPADDR"] = @remoteip

      # set LLADDR to sysconfig only for device on layer2 and only these which needs it
      # do not write incorrect LLADDR.
      if @qeth_layer2 && s390_correct_lladdr(@qeth_macaddress)
        busid = Ops.get_string(@Items, [@current, "hwinfo", "busid"], "")
        # sysfs id has changed from css0...
        sysfs_id = "/devices/qeth/#{busid}"
        log.info("busid #{busid}")
        if s390_device_needs_persistent_mac(sysfs_id, @Hardware)
          newdev["LLADDR"] = @qeth_macaddress
        end
      end

      newdev["NAME"] = @description

      newdev = setup_basic_device_options(newdev)
      newdev = setup_dhclient_options(newdev)

      case @type
      when "bond"
        i = 0
        @bond_slaves.each do |slave|
          newdev["BONDING_SLAVE#{i}"] = slave
          i += 1
        end

        # assign nil to rest BONDING_SLAVEn to remove them
        while i < @MAX_BOND_SLAVE
          newdev["BONDING_SLAVE#{i}"] = nil
          i += 1
        end

        newdev["BONDING_MODULE_OPTS"] = @bond_option
        newdev["BONDING_MASTER"] = "yes"

      when "vlan"
        newdev["ETHERDEVICE"] = @vlan_etherdevice
        newdev["VLAN_ID"] = @vlan_id

      when "br"
        newdev["BRIDGE_PORTS"] = @bridge_ports
        newdev["BRIDGE"] = "yes"
        newdev["BRIDGE_STP"] = "off"
        newdev["BRIDGE_FORWARDDELAY"] = "0"

      when "wlan"
        newdev["WIRELESS_MODE"] = @wl_mode
        newdev["WIRELESS_ESSID"] = @wl_essid
        newdev["WIRELESS_NWID"] = @wl_nwid
        newdev["WIRELESS_AUTH_MODE"] = @wl_auth_mode
        newdev["WIRELESS_WPA_PSK"] = @wl_wpa_psk
        newdev["WIRELESS_KEY_LENGTH"] = @wl_key_length
        # obsoleted by WIRELESS_KEY_0
        newdev["WIRELESS_KEY"] = "" # TODO: delete the varlable
        newdev["WIRELESS_KEY_0"] = Ops.get(@wl_key, 0, "")
        newdev["WIRELESS_KEY_1"] = Ops.get(@wl_key, 1, "")
        newdev["WIRELESS_KEY_2"] = Ops.get(@wl_key, 2, "")
        newdev["WIRELESS_KEY_3"] = Ops.get(@wl_key, 3, "")
        Ops.set(
          newdev,
          "WIRELESS_DEFAULT_KEY",
          Builtins.tostring(@wl_default_key)
        )
        Ops.set(newdev, "WIRELESS_NICK", @wl_nick)
        Ops.set(newdev, "WIRELESS_AP_SCANMODE", @wl_ap_scanmode)

        if @wl_wpa_eap != {}
          Ops.set(
            newdev,
            "WIRELESS_EAP_MODE",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_MODE", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_WPA_IDENTITY",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_IDENTITY", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_WPA_PASSWORD",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_PASSWORD", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_WPA_ANONID",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_ANONID", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_CLIENT_CERT",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_CLIENT_CERT", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_CLIENT_KEY",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_CLIENT_KEY", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_CLIENT_KEY_PASSWORD",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_CLIENT_KEY_PASSWORD", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_CA_CERT",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_CA_CERT", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_EAP_AUTH",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_AUTH", "")
          )
          Ops.set(
            newdev,
            "WIRELESS_PEAP_VERSION",
            Ops.get_string(@wl_wpa_eap, "WPA_EAP_PEAP_VERSION", "")
          )
        end

        newdev["WIRELESS_CHANNEL"] = @wl_channel
        newdev["WIRELESS_FREQUENCY"] = @wl_frequency
        newdev["WIRELESS_BITRATE"] = @wl_bitrate
        newdev["WIRELESS_AP"] = @wl_accesspoint
        newdev["WIRELESS_POWER"] = @wl_power ? "yes" : "no"

      when "ib"
        newdev["IPOIB_MODE"] = @ipoib_mode

      end

      if DriverType(@type) == "ctc"
        if Ops.get(NetworkConfig.Config, "WAIT_FOR_INTERFACES").nil? ||
            Ops.less_than(
              Ops.get_integer(NetworkConfig.Config, "WAIT_FOR_INTERFACES", 0),
              40
            )
          Ops.set(NetworkConfig.Config, "WAIT_FOR_INTERFACES", 40)
        end
      end

      if ["tun", "tap"].include?(@type)
        newdev = {
          "BOOTPROTO"        => "static",
          "STARTMODE"        => "auto",
          "TUNNEL"           => @type,
          "TUNNEL_SET_OWNER" => @tunnel_set_owner,
          "TUNNEL_SET_GROUP" => @tunnel_set_group
        }
      end

      # L3: bnc#585458
      # FIXME: INTERFACETYPE confuses sysconfig, bnc#458412
      # Only test when newdev has enough info for GetTypeFromIfcfg to work.
      implied_type = NetworkInterfaces.GetTypeFromIfcfg(newdev)
      if !implied_type.nil? && implied_type != @type
        newdev["INTERFACETYPE"] = @type
      end

      NetworkInterfaces.Name = Ops.get_string(@Items, [@current, "ifcfg"], "")
      NetworkInterfaces.Current = deep_copy(newdev)

      # bnc#752464 - can leak wireless passwords
      # useful only for debugging. Writes huge struct mostly filled by defaults.
      Builtins.y2debug("%1", NetworkInterfaces.ConcealSecrets1(newdev))

      Ops.set(@Items, [@current, "ifcfg"], "") if !NetworkInterfaces.Commit

      # configure bridge ports
      if @bridge_ports
        @bridge_ports.split.each { |bp| configure_as_bridge_port(bp) }
      end

      @modified = true
      @operation = nil
      true
    end

    # Remove a half-configured item.
    # @return [true] so that this can be used for the :abort callback
    def Rollback
      if getCurrentItem["commited"] == false
        log.info "rollback item #{@current}"
        if getCurrentItem.fetch("hwinfo", {}).empty?
          LanItems.Items.delete(@current)
        else
          if IsCurrentConfigured()
            if !getNetworkInterfaces.include?(getCurrentItem["ifcfg"])
              LanItems.Items[@current].delete("ifcfg")
            end
          end
        end
      end
      true
    end

    # Get the module configuration for the modules configured in the
    # interface section
    # @param [String] ay_device Device, for example eth0
    # @param [Array<Hash>] ay_modules list of modules from the AY profile
    # @return [Hash] the module map with module name and options
    def GetModuleForInterface(ay_device, ay_modules)
      ay_modules = deep_copy(ay_modules)
      ayret = {}
      ay_filtered = Builtins.filter(ay_modules) do |ay_m|
        Ops.get_string(ay_m, "device", "") == ay_device
      end

      if Ops.greater_than(Builtins.size(ay_filtered), 0)
        ayret = Ops.get(ay_filtered, 0, {})
      end

      deep_copy(ayret)
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

    def SetItem
      @operation = :edit
      @device = Ops.get_string(getCurrentItem, "ifcfg", "")

      NetworkInterfaces.Edit(@device)
      @type = Ops.get_string(getCurrentItem, ["hwinfo", "type"], "")

      @type = NetworkInterfaces.GetType(@device) if IsEmpty(@type)

      @alias = NetworkInterfaces.alias_num(@device)

      # general stuff
      devmap = deep_copy(NetworkInterfaces.Current)
      s390_devmap = s390_ReadQethConfig(
        Ops.get_string(getCurrentItem, ["hwinfo", "dev_name"], "")
      )

      @description = BuildDescription(@type, @device, devmap, @Hardware)

      SetDeviceVars(devmap, @SysconfigDefaults)
      SetS390Vars(s390_devmap, @s390_defaults)

      @hotplug = ""
      Builtins.y2debug("type=%1", @type)
      if Builtins.issubstring(@type, "-")
        @type = Builtins.regexpsub(@type, "([^-]+)-.*$", "\\1")
      end
      Builtins.y2debug("type=%1", @type)

      nil
    end

    def ProposeItem
      Builtins.y2milestone("Propose configuration for %1", getCurrentItem)
      @operation = nil
      return false if Select("") != true
      SetDefaultsForHW()
      @ipaddr = ""
      @netmask = ""
      @bootproto = "dhcp"
      # #176804
      if Storage.IsDeviceOnNetwork(NetworkStorage.getDevice("/")) != :no
        @startmode = "nfsroot"
        Builtins.y2milestone("startmode nfsroot")
      end
      NetworkInterfaces.Add
      @operation = :edit
      Ops.set(
        @Items,
        [@current, "ifcfg"],
        Ops.get_string(getCurrentItem, ["hwinfo", "dev_name"], "")
      )
      @description = HardwareName(
        [Ops.get_map(getCurrentItem, "hwinfo", {})],
        Ops.get_string(getCurrentItem, ["hwinfo", "dev_name"], "")
      )
      Commit()
      Builtins.y2milestone("After configuration propose %1", getCurrentItem)
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
    # @param [Hash] an s390 device description as obtained from AY profile
    def createS390Device(rule)
      Builtins.y2milestone("creating device s390 network device, #{rule}")

      Select("")
      @type = rule["type"] || ""
      @qeth_chanids = rule["chanids"] || ""
      @qeth_layer2 = rule.fetch("layer2", false)
      @qeth_portname = rule["portname"] || ""
      @chan_mode = rule["protocol"] || ""
      @iucv_user = rule["router"] || ""

      result = true
      # command to create device
      command1 = ""
      # command to find created device
      command2 = ""
      case @type
      when "hsi", "qeth"
        @portnumber_param = if Ops.greater_than(Builtins.size(@qeth_portnumber), 0)
                              Builtins.sformat("-n %1", @qeth_portnumber)
                            else
                              ""
                            end
        @portname_param = if Ops.greater_than(Builtins.size(@qeth_portname), 0)
                            Builtins.sformat("-p %1", @qeth_portname)
                          else
                            ""
                          end
        @options_param = if Ops.greater_than(Builtins.size(@qeth_options), 0)
                           Builtins.sformat("-o %1", @qeth_options)
                         else
                           ""
                         end
        command1 = Builtins.sformat(
          "qeth_configure %1 %2 %3 %4 %5 1",
          @options_param,
          @qeth_layer2 ? "-l" : "",
          @portname_param,
          @portnumber_param,
          @qeth_chanids
        )
        command2 = Builtins.sformat(
          "ls /sys/devices/qeth/%1/net/|head -n1|tr -d '\n'",
          Ops.get(Builtins.splitstring(@qeth_chanids, " "), 0, "")
        )
      when "ctc"
        # chan_ids (read, write), protocol
        command1 = Builtins.sformat(
          "ctc_configure %1 1 %2",
          @qeth_chanids,
          @chan_mode
        )
        command2 = Builtins.sformat(
          "ls /sys/devices/ctcm/%1/net/|head -n1|tr -d '\n'",
          Ops.get(Builtins.splitstring(@qeth_chanids, " "), 0, "")
        )
      when "lcs"
        # chan_ids (read, write), protocol
        command1 = Builtins.sformat(
          "ctc_configure %1 1 %2",
          @qeth_chanids,
          @chan_mode
        )
        command2 = Builtins.sformat(
          "ls /sys/devices/lcs/%1/net/|head -n1|tr -d '\n'",
          Ops.get(Builtins.splitstring(@qeth_chanids, " "), 0, "")
        )
      when "iucv"
        # router
        command1 = Builtins.sformat("iucv_configure %1 1", @iucv_user)
        command2 = Builtins.sformat(
          "ls /sys/devices/%1/*/net/|head -n1|tr -d '\n'",
          @type
        )
      else
        Builtins.y2error("Unsupported type : %1", @type)
      end
      Builtins.y2milestone("execute %1", command1)
      output1 = Convert.convert(
        SCR.Execute(path(".target.bash_output"), command1),
        from: "any",
        to:   "map <string, any>"
      )
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

  private

    # This helper allows YARD to extract DSL-defined attributes.
    # Unfortunately YARD has problems with the Capitalized ones,
    # so those must be done manually.
    # @!macro [attach] publish_variable
    #  @!attribute $1
    #  @return [$2]
    def self.publish_variable(name, type)
      publish variable: name, type: type
    end

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
      Host.set_names(ip, [])
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
          driver = Convert.convert(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat(
                "driver=$(ls -l /sys/class/net/%1/device/driver);echo ${driver##*/}|tr -d '\n'",
                device
              )
            ),
            from: "any",
            to:   "map <string, any>"
          )
          device_type = ""
          chanids = ""
          portname = ""
          protocol = ""
          if Ops.get_integer(driver, "exit", -1) == 0
            case Ops.get_string(driver, "stdout", "")
            when "qeth"
              device_type = Ops.get_string(driver, "stdout", "")
            when "ctcm"
              device_type = "ctc"
            when "netiucv"
              device_type = "iucv"
            else
              Builtins.y2error(
                "unknown driver type :%1",
                Ops.get_string(driver, "stdout", "")
              )
            end
          else
            Builtins.y2error("%1", driver)
            next
          end
          chan_ids = Convert.convert(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat(
                "for i in $(seq 0 2);do chanid=$(ls -l /sys/class/net/%1/device/cdev$i);echo ${chanid##*/};done|tr '\n' ' '",
                device
              )
            ),
            from: "any",
            to:   "map <string, any>"
          )
          if Ops.greater_than(
            Builtins.size(Ops.get_string(chan_ids, "stdout", "")),
            0
            )
            chanids = String.CutBlanks(Ops.get_string(chan_ids, "stdout", ""))
          end
          port_name = Convert.convert(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat(
                "cat /sys/class/net/%1/device/portname|tr -d '\n'",
                device
              )
            ),
            from: "any",
            to:   "map <string, any>"
          )
          if Ops.greater_than(
            Builtins.size(Ops.get_string(port_name, "stdout", "")),
            0
            )
            portname = String.CutBlanks(Ops.get_string(port_name, "stdout", ""))
          end
          proto = Convert.convert(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat(
                "cat /sys/class/net/%1/device/protocol|tr -d '\n'",
                device
              )
            ),
            from: "any",
            to:   "map <string, any>"
          )
          if Ops.greater_than(
            Builtins.size(Ops.get_string(proto, "stdout", "")),
            0
            )
            protocol = String.CutBlanks(Ops.get_string(proto, "stdout", ""))
          end
          layer2_ret = SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "grep -q 1 /sys/class/net/%1/device/layer2",
              device
          )
                   )
          layer2 = layer2_ret == 0
          Ops.set(ay, ["s390-devices", device], "type" => device_type)
          if Ops.greater_than(Builtins.size(chanids), 0)
            Ops.set(ay, ["s390-devices", device, "chanids"], chanids)
          end
          if Ops.greater_than(Builtins.size(portname), 0)
            Ops.set(ay, ["s390-devices", device, "portname"], portname)
          end
          if Ops.greater_than(Builtins.size(protocol), 0)
            Ops.set(ay, ["s390-devices", device, "protocol"], protocol)
          end
          Ops.set(ay, ["s390-devices", device, "layer2"], true) if layer2
          port0 = Convert.convert(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat(
                "port0=$(ls -l /sys/class/net/%1/device/cdev0);echo ${port0##*/}|tr -d '\n'",
                device
              )
            ),
            from: "any",
            to:   "map <string, any>"
          )
          Builtins.y2milestone("port0 %1", port0)
          if Ops.greater_than(
            Builtins.size(Ops.get_string(port0, "stdout", "")),
            0
            )
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
        configured.each do |id, _|
          @current = id # for GetItemUdev

          name = GetItemUdev("NAME").to_s
          rule = ["ATTR{address}", "KERNELS"].find { |r| !GetItemUdev(r).to_s.empty? }

          next if !rule || name.empty?

          ay["net-udev"] = {
            name => {
              "rule"  => rule,
              "name"  => name,
              "value" => GetItemUdev(rule)
            }
          }
        end
      end

      Builtins.y2milestone("AY profile %1", ay)
      deep_copy(ay)
    end

  public

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
    publish_variable :modified, "boolean"
    publish_variable :operation, "symbol"
    publish_variable :force_restart, "boolean"
    publish_variable :description, "string"
    publish_variable :type, "string"
    publish_variable :device, "string"
    publish_variable :alias, "string"
    # the index into {#Items}
    publish_variable :current, "integer"
    publish_variable :hotplug, "string"
    # @attribute Requires
    publish_variable :Requires, "list <string>"
    publish_variable :bootproto, "string"
    publish_variable :ipaddr, "string"
    publish_variable :remoteip, "string"
    publish_variable :netmask, "string"
    publish_variable :set_default_route, "boolean"
    publish_variable :prefix, "string"
    publish_variable :startmode, "string"
    publish_variable :ifplugd_priority, "string"
    publish_variable :mtu, "string"
    publish_variable :ethtool_options, "string"
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
    publish_variable :vlan_id, "string"
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
    publish_variable :nm_name, "string"
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
    publish function: :GetSlaveCandidates, type: "list <integer> (string, boolean (string, integer))"
    publish function: :GetBondableInterfaces, type: "list <integer> (string)"
    publish function: :GetBridgeableInterfaces, type: "list <integer> (string)"
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
    publish function: :SelectHW, type: "void (integer)"
    publish function: :FreeDevices, type: "list (string)"
    publish function: :SetDefaultsForHW, type: "void ()"
    publish function: :SetDeviceVars, type: "void (map, map)"
    publish function: :Select, type: "boolean (string)"
    publish function: :Commit, type: "boolean ()"
    publish function: :Rollback, type: "boolean ()"
    publish function: :GetModuleForInterface, type: "map (string, list <map>)"
    publish function: :DeleteItem, type: "void ()"
    publish function: :SetItem, type: "void ()"
    publish function: :ProposeItem, type: "boolean ()"
    publish function: :setDriver, type: "void (string)"
    publish function: :enableCurrentEditButton, type: "boolean ()"
    publish function: :createS390Device, type: "boolean ()"
  end

  LanItems = LanItemsClass.new
  LanItems.main
end
