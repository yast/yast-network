# encoding: utf-8

#***************************************************************************
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
#**************************************************************************
require "yast"

module Yast
  class LanItemsClass < Module
    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "NetworkInterfaces"
      Yast.import "ProductFeatures"
      Yast.import "NetworkConfig"
      Yast.import "NetworkStorage"
      Yast.include self, "network/complex.rb"
      Yast.include self, "network/routines.rb"
      Yast.include self, "network/lan/s390.rb"
      Yast.include self, "network/lan/udev.rb"

      # Hardware information
      # @see #ReadHardware
      @Items = {}
      @Hardware = []
      @udev_net_rules = {}
      @driver_options = {}

      # FIXME: what's the difference against "device" defined below?
      # some refactoring led to interfacename = device in SetItem.
      # Probably, interfacename is used outside. It is only set in
      # this file.
      @interfacename = ""

      # used at autoinstallation time
      @autoinstall_settings = {}

      # Data was modified?
      @modified = false
      # current selected HW
      @hw = {}

      # Which operation is pending?
      @operation = nil

      # in special cases when rcnetwork reload is not enought
      @force_restart = false

      @description = ""

      #unique - only for backward compatibility
      #global string unique = "";

      @type = ""
      @device = ""
      #FIXME: always empty string - remove all occuriences
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
      @usercontrol = false
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

      #bond options
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
      @nilliststring = nil # to save some casting

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
      @tunnel_set_persistent = true
      @tunnel_set_owner = ""
      @tunnel_set_group = ""


      # propose options
      @proposal_valid = false
      @nm_proposal_valid = false

      # NetworkModules:: name
      @nm_name = ""
      @nm_name_old = nil

      #this is the map of kernel modules vs. requested firmware
      #non-empty keys are firmware packages shipped by SUSE
      @request_firmware = {
        "atmel_pci"      => "atmel-firmware",
        "atmel_cs"       => "atmel-firmware",
        "at76_usb"       => "atmel-firmware",
        "ipw2100"        => "ipw-firmware",
        "ipw2200"        => "ipw-firmware",
        "ipw3945"        => "ipw-firmware",
        "iwl1000"        => "kernel-firmware",
        "iwl3945"        => "kernel-firmware",
        "iwl4965"        => "kernel-firmware",
        "iwl5000"        => "kernel-firmware",
        "iwl5150"        => "kernel-firmware",
        "iwl6000"        => "kernel-firmware",
        "b43"            => "b43-fwcutter",
        "b43-pci-bridge" => "b43-fwcutter",
        "rt73usb"        => "ralink-firmware",
        "rt61pci"        => "ralink-firmware",
        "bcm43xx"        => "",
        "prism54"        => "",
        "spectrum_cs"    => "",
        "zd1201"         => "",
        "zd1211rw"       => "",
        "acx"            => "",
        "rt73usb"        => "",
        "prism54usb"     => ""
      }

      Yast.include self, "network/hardware.rb"

      # the defaults here are what sysconfig defaults to
      # (as opposed to what a new interface gets, in {#Select)}
      @SysconfigDefaults = {
        "BOOTPROTO"                    => "static",
        "IPADDR"                       => "",
        "PREFIXLEN"                    => "",
        "REMOTE_IPADDR"                => "",
        "NETMASK"                      => "",
        "MTU"                          => "",
        "LLADDR"                       => "00:00:00:00:00:00",
        "ETHTOOL_OPTIONS"              => "",
        "NAME"                         => "",
        "STARTMODE"                    => "manual",
        "IFPLUGD_PRIORITY"             => "0",
        "USERCONTROL"                  => "no",
        "WIRELESS_MODE"                => "Managed",
        "WIRELESS_ESSID"               => "",
        "WIRELESS_NWID"                => "",
        "WIRELESS_AUTH_MODE"           => "open",
        "WIRELESS_WPA_PSK"             => "",
        "WIRELESS_KEY_LENGTH"          => "128",
        "WIRELESS_KEY"                 => "",
        "WIRELESS_KEY_0"               => "",
        "WIRELESS_KEY_1"               => "",
        "WIRELESS_KEY_2"               => "",
        "WIRELESS_KEY_3"               => "",
        "WIRELESS_DEFAULT_KEY"         => "0",
        "WIRELESS_NICK"                => "",
        "WIRELESS_CLIENT_CERT"         => "",
        "WIRELESS_CA_CERT"             => "",
        "WIRELESS_CHANNEL"             => "",
        "WIRELESS_FREQUENCY"           => "",
        "WIRELESS_BITRATE"             => "auto",
        "WIRELESS_AP"                  => "",
        "WIRELESS_POWER"               => "",
        # aliases = devmap["_aliases"]:$[]; // ?
        "WIRELESS_EAP_MODE"            => "",
        "WIRELESS_WPA_IDENTITY"        => "",
        "WIRELESS_WPA_PASSWORD"        => "",
        "WIRELESS_WPA_ANONID"          => "",
        "WIRELESS_CLIENT_CERT"         => "",
        "WIRELESS_CLIENT_KEY"          => "",
        "WIRELESS_CLIENT_KEY_PASSWORD" => "",
        "WIRELESS_CA_CERT"             => "",
        "WIRELESS_EAP_AUTH"            => "",
        "WIRELESS_PEAP_VERSION"        => "",
        "WIRELESS_AP_SCANMODE"         => "1",
        # default options for bonding (bnc#404449)
        "BONDING_MODULE_OPTS"          => "mode=active-backup miimon=100",
        # defaults for tun/tap devices
        "TUNNEL_SET_OWNER"             => "",
        "TUNNEL_SET_GROUP"             => "",
        "TUNNEL_SET_PERSISTENT"        => "yes"
      }

      # Default values used when creating an emulated NIC for physical s390 hardware.
      @s390_defaults = {
        "CHAN_MODE"       => "0",
        "QETH_PORTNAME"   => "",
        "QETH_PORTNUMBER" => "",
        "QETH_OPTIONS"    => "",
        "QETH_LAYER2"     => "no",
        "QETH_CHANIDS"    => "",
        "IPA_TAKEOVER"    => "no",
        "IUCV_USER"       => ""
      }

      # ifplugd sometimes does not work for wifi
      # so wired needs higher priority to override it
      @ifplugd_priorities = { "eth" => "20", "wlan" => "10" }
    end

    # Returns configuration of item (see LanItems::Items) with given id.
    def GetLanItem(itemId)
      Ops.get_map(@Items, itemId, {})
    end

    # Returns configuration for currently modified item.
    def getCurrentItem
      GetLanItem(@current)
    end

    # Returns true if the item (see LanItems::Items) has
    # netconfig configuration.
    def IsItemConfigured(itemId)
      ret = false

      if Ops.greater_than(
          Builtins.size(Ops.get_string(GetLanItem(itemId), "ifcfg", "")),
          0
        )
        ret = true
      end

      Builtins.y2milestone("is item %1 configured? %2", itemId, ret)

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
    def GetDeviceName(itemId)
      lanItem = GetLanItem(itemId)

      Ops.get_string(
        lanItem,
        "ifcfg",
        Ops.get_string(lanItem, ["hwinfo", "dev_name"], "")
      )
    end

    # Returns device name for current lan item (see LanItems::current)
    def GetCurrentName
      GetDeviceName(@current)
    end

    # Returns device type for particular lan item
    def GetDeviceType(itemId)
      NetworkInterfaces.GetType(GetDeviceName(itemId))
    end

    # Returns ifcfg configuration for particular item
    def GetDeviceMap(itemId)
      return nil if !IsItemConfigured(itemId)

      devname = GetDeviceName(itemId)
      devtype = NetworkInterfaces.GetType(devname)

      Convert.convert(
        Ops.get(NetworkInterfaces.FilterDevices("netcard"), [devtype, devname]),
        :from => "any",
        :to   => "map <string, any>"
      )
    end

    # Returns udev rule known for particular item
    def GetItemUdevRule(itemId)
      Ops.get_list(GetLanItem(itemId), ["udev", "net"], [])
    end

    def ReadUdevDriverRules
      Builtins.y2milestone("Reading udev rules ...")
      @udev_net_rules = Convert.convert(
        SCR.Read(path(".udev_persistent.net")),
        :from => "any",
        :to   => "map <string, any>"
      )

      Builtins.y2milestone("Reading driver options ...")
      Builtins.foreach(SCR.Dir(path(".modules.options"))) do |driver|
        pth = Builtins.sformat(".modules.options.%1", driver)
        #  driver_options[driver] = SCR::Read(topath(pth));
        Builtins.foreach(
          Convert.convert(
            SCR.Read(Builtins.topath(pth)),
            :from => "any",
            :to   => "map <string, string>"
          )
        ) do |key, value|
          Ops.set(
            @driver_options,
            driver,
            Builtins.sformat(
              "%1%2%3=%4",
              Ops.get_string(@driver_options, driver, ""),
              Ops.greater_than(
                Builtins.size(Ops.get_string(@driver_options, driver, "")),
                0
              ) ? " " : "",
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

    def SetItemUdev(rule_key, rule_val)
      ReplaceItemUdev(rule_key, rule_key, rule_val)
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
          :from => "list",
          :to   => "list <integer>"
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
          SetLinkDown(dev_name)

          @force_restart = true
        end
        net_rules = Builtins.add(
          net_rules,
          Builtins.mergestring(item_udev_net, ", ")
        )
      end

      Builtins.y2milestone("write net udev rules: %1", net_rules)

      SCR.Write(path(".udev_persistent.rules"), net_rules)
      SCR.Write(path(".udev_persistent.nil"), [])

      SCR.Execute(path(".target.bash"), "udevadm control --reload")

      # When configuring a new s390 card, we neglect to fill
      # its Items[i, "udev", "net"], causing jumbled names (bnc#721520)
      # The udev trigger will will make udev write the persistent names
      # (which it already has done, but we have overwritten them now).
      SCR.Execute(
        path(".target.bash"),
        "udevadm trigger --subsystem-match=net --action=add"
      )

      true
    end

    def WriteUdevDriverRules
      udev_drivers_rules = {}

      Builtins.foreach(
        Convert.convert(
          Map.Keys(@Items),
          :from => "list",
          :to   => "list <integer>"
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
          :from => "map <string, any>",
          :to   => "map <string, string>"
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

      nil
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
    # Function sets internal variable, which indicates, that any
    # settings were modified, to "false"
    def UnsetModified
      @modified = false

      nil
    end

    def AddNew
      @current = Builtins.size(@Items)
      Ops.set(@Items, @current, { "commited" => false })
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
        ret = ret && Ops.get_string(s390_config, "QETH_LAYER2", "no") == "yes"
      end

      ifcfg = GetDeviceMap(itemId)

      itemBondMaster = Ops.get(bonded, devname, "")

      if IsNotEmpty(itemBondMaster) && bondMaster != itemBondMaster
        Builtins.y2debug(
          "IsBondable: excluding lan item (%1: %2) for %3 - is already bonded",
          itemId,
          devname,
          GetDeviceName(@current)
        )
        return false
      end

      return ret if ifcfg == nil

      # filter the eth devices (BOOTPROTO=none)
      # don't care about STARTMODE (see bnc#652987c6)
      ret = ret && Ops.get_string(ifcfg, "BOOTPROTO", "") == "none"

      ret
    end

    # Decides if given lan item can be enslaved in a bridge.
    #
    # @param [String] bridgeMaster  name of master device
    # @param [Fixnum] itemId        index into LanItems::Items
    # TODO: bridgeMaster is not used yet bcs detection of bridge master
    # for checked device is missing.
    def IsBridgeable(bridgeMaster, itemId)
      ifcfg = GetDeviceMap(itemId)

      # no netconfig configuration has been found so nothing
      # blocks using the device as bridge slave
      return true if ifcfg == nil

      devname = GetDeviceName(itemId)
      bonded = BuildBondIndex()

      if Ops.get(bonded, devname) != nil
        Builtins.y2debug(
          "IsBridgeable: excluding lan item (%1: %2) - is bonded",
          itemId,
          devname
        )
        return false
      end

      devtype = GetDeviceType(itemId)

      # exclude forbidden configurations
      if devtype == "br"
        Builtins.y2debug(
          "IsBridgeable: excluding lan item (%1: %2) - is bridge",
          itemId,
          devname
        )
        return false
      end

      if Ops.get_string(ifcfg, "STARTMODE", "") == "nfsroot"
        Builtins.y2debug(
          "IsBridgeable: excluding lan item (%1: %2) - is nfsroot",
          itemId,
          devname
        )
        return false
      end

      true
    end

    # Iterates over all items and lists those for which given validator returns
    # true.
    #
    # @param [boolean (string, integer)] validator   a reference to function which checks if an interface
    #                      can be enslaved. Validator takes one argument - itemId.
    # @return  [Array] of lan item ids (see LanItems::Items)
    def GetSlaveCandidates(master, validator)
      validator = deep_copy(validator)
      if validator == nil
        Builtins.y2error("GetSlaveCandidates: needs a validator.")
        return []
      end
      if IsEmpty(master)
        Builtins.y2error("GetSlaveCandidates: master device name is required.")
        return []
      end

      result = []

      Builtins.foreach(@Items) do |itemId, attribs|
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

    # get list of all configurations for "netcard" macro in NetworkInterfaces module
    def getNetworkInterfaces
      confs = []
      configurations = NetworkInterfaces.FilterDevices("netcard")

      Builtins.foreach(
        Builtins.splitstring(
          Ops.get(NetworkInterfaces.CardRegex, "netcard", ""),
          "|"
        )
      ) do |devtype|
        Builtins.foreach(
          Convert.convert(
            Map.Keys(Ops.get_map(configurations, devtype, {})),
            :from => "list",
            :to   => "list <string>"
          )
        ) { |file| confs = Builtins.add(confs, file) }
      end

      deep_copy(confs)
    end

    def FindAndSelect(device)
      found = false
      Builtins.foreach(
        Convert.convert(
          @Items,
          :from => "map <integer, any>",
          :to   => "map <integer, map <string, any>>"
        )
      ) do |i, a|
        if Ops.get_string(a, "ifcfg", "") == device
          found = true
          @current = i
        end
      end
      found
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
          :from => "map <integer, any>",
          :to   => "map <integer, map <string, any>>"
        )
      ) do |i, a|
        if Ops.get_string(a, ["hwinfo", "dev_name"], "") == device
          ret = i
          raise Break
        end
      end

      ret
    end

    # preinitializates @Items according info on physically detected network cards
    def ReadHw
      @Items = {}
      @Hardware = ReadHardware("netcard")
      # Hardware = [$["active":true, "bus":"pci", "busid":"0000:02:00.0", "dev_name":"wlan0", "drivers":[$["active":true, "modprobe":true, "modules":[["ath5k" , ""]]]], "link":true, "mac":"00:22:43:37:55:c3", "modalias":"pci:v0000168Cd0000001Csv00001A3Bsd00001026bc02s c00i00", "module":"ath5k", "name":"AR242x 802.11abg Wireless PCI Express Adapter", "num":0, "options":"", "re quires":[], "sysfs_id":"/devices/pci0000:00/0000:00:1c.1/0000:02:00.0", "type":"wlan", "udi":"/org/freedeskto p/Hal/devices/pci_168c_1c", "wl_auth_modes":["open", "sharedkey", "wpa-psk", "wpa-eap"], "wl_bitrates":nil, " wl_channels":["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"], "wl_enc_modes":["WEP40", "WEP104", "T KIP", "CCMP"]], $["active":true, "bus":"pci", "busid":"0000:01:00.0", "dev_name":"eth0", "drivers":[$["active ":true, "modprobe":true, "modules":[["atl1e", ""]]]], "link":false, "mac":"00:23:54:3f:7c:c3", "modalias":"pc i:v00001969d00001026sv00001043sd00008324bc02sc00i00", "module":"atl1e", "name":"L1 Gigabit Ethernet Adapter", "num":1, "options":"", "requires":[], "sysfs_id":"/devices/pci0000:00/0000:00:1c.3/0000:01:00.0", "type":"et h", "udi":"/org/freedesktop/Hal/devices/pci_1969_1026", "wl_auth_modes":nil, "wl_bitrates":nil, "wl_channels" :nil, "wl_enc_modes":nil]];
      ReadUdevDriverRules()

      udev_drivers_rules = Convert.convert(
        SCR.Read(path(".udev_persistent.drivers")),
        :from => "any",
        :to   => "map <string, any>"
      )
      Builtins.foreach(@Hardware) do |hwitem|
        udev_net = Ops.get_string(hwitem, "dev_name", "") != "" ?
          Ops.get_list(
            @udev_net_rules,
            Ops.get_string(hwitem, "dev_name", ""),
            []
          ) :
          []
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
          {
            "hwinfo" => hwitem,
            "udev"   => { "net" => udev_net, "driver" => mod }
          }
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

      # match configurations to Items list with hwinfo
      Builtins.foreach(getNetworkInterfaces) do |confname|
        pos = nil
        val = {}
        Builtins.foreach(
          Convert.convert(
            @Items,
            :from => "map <integer, any>",
            :to   => "map <integer, map <string, any>>"
          )
        ) do |key, value|
          if Ops.get_string(value, ["hwinfo", "dev_name"], "") == confname
            pos = key
            val = deep_copy(value)
          end
        end
        if pos == nil
          pos = Builtins.size(@Items)
          Ops.set(@Items, pos, {})
        end
        Ops.set(@Items, [pos, "ifcfg"], confname)
      end

      # add to Items also virtual devices (configurations) without hwinfo
      Builtins.foreach(getNetworkInterfaces) do |confname|
        already = false
        Builtins.foreach(
          Convert.convert(
            Map.Keys(@Items),
            :from => "list",
            :to   => "list <integer>"
          )
        ) do |key|
          if confname == Ops.get_string(@Items, [key, "ifcfg"], "")
            already = true
            raise Break
          end
        end
        if !already
          AddNew()
          Ops.set(@Items, @current, { "ifcfg" => confname })
        end
      end
      Builtins.y2milestone("Read Configuration LanItems::Items %1", @Items)

      nil
    end

    def GetDescr
      descr = []
      Builtins.foreach(
        Convert.convert(
          @Items,
          :from => "map <integer, any>",
          :to   => "map <integer, map <string, any>>"
        )
      ) do |key, value|
        if Builtins.haskey(value, "table_descr") &&
            Ops.greater_than(
              Builtins.size(Ops.get_map(@Items, [key, "table_descr"], {})),
              1
            )
          descr = Builtins.add(
            descr,
            {
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
            }
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
        :from => "map",
        :to   => "map <string, map>"
      )

      Builtins.foreach(bond_devs) do |bond_master, value|
        Builtins.foreach(GetBondSlaves(bond_master)) do |slave|
          index = Builtins.add(index, slave, bond_master)
        end
      end

      Builtins.y2debug("bond slaves index: %1", index)

      deep_copy(index)
    end

    def BuildLanOverview
      overview = []
      links = []
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

      Builtins.foreach(
        Convert.convert(
          Map.Keys(@Items),
          :from => "list",
          :to   => "list <integer>"
        )
      ) do |key|
        rich = ""
        ip = _("Not configured")
        descr = Ops.get_string(@Items, [key, "hwinfo", "name"], "")
        dev = ""
        note = ""
        @type = Ops.get_string(@Items, [key, "hwinfo", "type"], "")
        descr = CheckEmptyName(@type, descr)
        bullets = []
        if IsNotEmpty(Ops.get_string(@Items, [key, "ifcfg"], ""))
          NetworkInterfaces.Select(Ops.get_string(@Items, [key, "ifcfg"], ""))
          if IsEmpty(@type)
            @type = NetworkInterfaces.GetType(
              Ops.get_string(@Items, [key, "ifcfg"], "")
            )
          end
          descr = BuildDescription(
            @type,
            NetworkInterfaces.GetType(
              Ops.get_string(@Items, [key, "ifcfg"], "")
            ),
            NetworkInterfaces.Current,
            [Ops.get_map(@Items, [key, "hwinfo"], {})]
          )
          dev = NetworkInterfaces.Name #NetworkInterfaces::device_name(type, NetworkInterfaces::Name);
          ip = DeviceProtocol(NetworkInterfaces.Current)
          status = DeviceStatus(
            @type,
            NetworkInterfaces.device_num(NetworkInterfaces.Name),
            NetworkInterfaces.Current
          )

          startmode_descr = Ops.get_locale(
            startmode_descrs,
            Ops.get_string(NetworkInterfaces.Current, "STARTMODE", ""),
            _("Started manually")
          )

          bullets = [
            Builtins.sformat(_("Device Name: %1"), dev),
            startmode_descr
          ]

          if Ops.get_string(NetworkInterfaces.Current, "STARTMODE", "") != "managed"
            if ip != "NONE"
              prefixlen = Ops.get_string(
                NetworkInterfaces.Current,
                "PREFIXLEN",
                ""
              )
              if Ops.greater_than(Builtins.size(ip), 0)
                descr2 = Builtins.sformat(
                  "%1 %2",
                  _("IP address assigned using"),
                  ip
                )
                if !Builtins.issubstring(ip, "DHCP")
                  descr2 = Ops.greater_than(Builtins.size(prefixlen), 0) ?
                    Builtins.sformat(_("IP address: %1/%2"), ip, prefixlen) :
                    Builtins.sformat(
                      _("IP address: %1, subnet mask %2"),
                      ip,
                      Ops.get_string(NetworkInterfaces.Current, "NETMASK", "")
                    )
                end
                bullets = Ops.add(bullets, [descr2])
              end
            end
            # build aliases overview
            if Ops.greater_than(
                Builtins.size(
                  Ops.get_map(NetworkInterfaces.Current, "_aliases", {})
                ),
                0
              ) &&
                !NetworkService.IsManaged
              Builtins.foreach(
                Ops.get_map(NetworkInterfaces.Current, "_aliases", {})
              ) do |key2, desc|
                parameters = Builtins.sformat(
                  "%1/%2",
                  Ops.get_string(desc, "IPADDR", ""),
                  Ops.get_string(desc, "PREFIXLEN", "")
                )
                bullets = Builtins.add(
                  bullets,
                  Builtins.sformat(
                    "%1 (%2)",
                    Ops.get_string(desc, "LABEL", ""),
                    parameters
                  )
                )
              end
            end
          end

          if @type == "wlan" &&
              !(Ops.get_string(
                NetworkInterfaces.Current,
                "WIRELESS_AUTH_MODE",
                ""
              ) != "open") &&
              IsEmpty(
                Ops.get_string(NetworkInterfaces.Current, "WIRELESS_KEY_0", "")
              )
            # avoid colons
            dev = Builtins.mergestring(Builtins.splitstring(dev, ":"), "/")
            href = Ops.add("lan--wifi-encryption-", dev)
            # interface summary: WiFi without encryption
            warning = HTML.Colorize(_("Warning: no encryption is used."), "red")
            status = Ops.add(
              Ops.add(Ops.add(Ops.add(status, " "), warning), " "),
              # Hyperlink: Change the configuration of an interface
              Hyperlink(href, _("Change."))
            )
            links = Builtins.add(links, href)
          end

          if @type == "bond"
            bullets = Builtins.add(
              bullets,
              Builtins.sformat(
                "%1: %2",
                _("Bonding slaves"),
                Builtins.mergestring(GetBondSlaves(dev), " ")
              )
            )
          end

          bond_index = BuildBondIndex()
          bond_master = Ops.get(
            bond_index,
            Ops.get_string(@Items, [key, "ifcfg"], ""),
            ""
          )

          if Ops.greater_than(Builtins.size(bond_master), 0)
            note = Builtins.sformat(_("enslaved in %1"), bond_master)
            bullets = Builtins.add(
              bullets,
              Builtins.sformat("%1: %2", _("Bonding master"), bond_master)
            )
          end

          overview = Builtins.add(overview, Summary.Device(descr, status))
        else
          overview = Builtins.add(
            overview,
            Summary.Device(descr, Summary.NotConfigured)
          )
        end
        conn = HTML.Bold(
          Ops.get_boolean(@Items, [key, "hwinfo", "link"], false) == true ?
            "" :
            Builtins.sformat("(%1)", _("Not connected"))
        )
        if Builtins.size(Ops.get_map(@Items, [key, "hwinfo"], {})) == 0
          conn = HTML.Bold(Builtins.sformat("(%1)", _("No hwinfo")))
        end
        mac_dev = Ops.add(
          Ops.add(
            HTML.Bold("MAC : "),
            Ops.get_string(@Items, [key, "hwinfo", "mac"], "")
          ),
          "<br>"
        )
        bus_id = Ops.add(
          Ops.add(
            HTML.Bold("BusID : "),
            Ops.get_string(@Items, [key, "hwinfo", "busid"], "")
          ),
          "<br>"
        )
        if IsNotEmpty(Ops.get_string(@Items, [key, "hwinfo", "mac"], ""))
          rich = Ops.add(Ops.add(Ops.add(rich, " "), conn), "<br>")
          rich = Ops.add(rich, mac_dev)
        end
        if IsNotEmpty(Ops.get_string(@Items, [key, "hwinfo", "busid"], ""))
          rich = Ops.add(rich, bus_id)
        end
        # display it only if we need it, don't duplicate "dev" above
        if IsNotEmpty(Ops.get_string(@Items, [key, "hwinfo", "dev_name"], "")) &&
            IsEmpty(Ops.get_string(@Items, [key, "ifcfg"], ""))
          dev_name = Builtins.sformat(
            _("Device Name: %1"),
            Ops.get_string(@Items, [key, "hwinfo", "dev_name"], "")
          )
          dev_name_r = Ops.add(HTML.Bold(dev_name), "<br>")
          rich = Ops.add(rich, dev_name_r)
        end
        rich = Ops.add(HTML.Bold(descr), rich)
        if IsEmpty(Ops.get_string(@Items, [key, "hwinfo", "dev_name"], "")) &&
            Ops.greater_than(
              Builtins.size(Ops.get_map(@Items, [key, "hwinfo"], {})),
              0
            ) &&
            !Arch.s390
          rich = Ops.add(
            rich,
            _(
              "<p>Unable to configure the network card because the kernel device (eth0, wlan0) is not present. This is mostly caused by missing firmware (for wlan devices). See dmesg output for details.</p>"
            )
          )
        elsif IsNotEmpty(Ops.get_string(@Items, [key, "ifcfg"], ""))
          rich = Ops.add(rich, HTML.List(bullets))
        else
          rich = Ops.add(
            rich,
            _(
              "<p>The device is not configured. Press <b>Edit</b>\nto configure.</p>\n"
            )
          )

          curr = @current
          @current = key
          if needFirmwareCurrentItem
            fw = GetFirmwareForCurrentItem()
            rich = Ops.add(
              rich,
              Builtins.sformat(
                "%1 : %2",
                _("Needed firmware"),
                fw != "" ? fw : _("unknown")
              )
            )
          end
          @current = curr
        end
        Ops.set(
          @Items,
          [key, "table_descr"],
          { "rich_descr" => rich, "table_descr" => [descr, ip, dev, note] }
        )
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


    # Check if the given device has any virtual alias.
    # @param dev device to be checked
    # @return true if there are some aliases
    def InterfaceHasAliases
      NetworkInterfaces.HasAliases(
        Ops.get_string(@Items, [@current, "ifcfg"], "")
      )
    end

    # Select the hardware component
    # @param hw the component
    def SelectHWMap(hardware)
      hardware = deep_copy(hardware)
      #    sysfs_id = hardware["sysfs_id"]:"";
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
        Convert.convert(
          Ops.get(hardware, "wl_auth_modes", @nilliststring),
          :from => "any",
          :to   => "list <string>"
        ),
        "no-encryption"
      )
      @wl_enc_modes = Convert.convert(
        Ops.get(hardware, "wl_enc_modes", @nilliststring),
        :from => "any",
        :to   => "list <string>"
      )
      @wl_channels = Convert.convert(
        Ops.get(hardware, "wl_channels", @nilliststring),
        :from => "any",
        :to   => "list <string>"
      )
      @wl_bitrates = Convert.convert(
        Ops.get(hardware, "wl_bitrates", @nilliststring),
        :from => "any",
        :to   => "list <string>"
      )

      mac = Ops.get_string(hardware, "mac", "")
      busid = Ops.get_string(hardware, "busid", "")


      #    nm_name = createHwcfgName(hardware, type);

      @interfacename = Ops.get_string(hardware, "dev_name", "")

      # name of ifcfg
      # eth, tr, not on s390 (#38819)
      if !Arch.s390 && mac != nil && mac != "" && mac != "00:00:00:00:00:00"
        @device = Ops.add("id-", Ops.get_string(hardware, "mac", ""))
      # iucv already filled in from lan/hardware.ycp (#42212)
      elsif @type == "iucv"
        Builtins.y2debug("IUCV: %1", @device)
      # other devs
      elsif busid != nil && busid != ""
        @device = Ops.add(
          Ops.add(Ops.add("bus-", Ops.get_string(hardware, "bus", "")), "-"),
          Ops.get_string(hardware, "busid", "")
        )
      # USB, PCMCIA
      elsif Ops.get_string(hardware, "hotplug", "") != ""
        @device = Ops.add("bus-", Ops.get_string(hardware, "hotplug", ""))
      else
        # dummy
        Builtins.y2milestone("No detailed HW info: %1", @device)
      end

      Builtins.y2milestone("hw=%1", hardware)
      Builtins.y2milestone("device=%1", @device)
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
        devid = 0 if devid == nil
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

    # Return 10 free aliases
    # @param [String] type device type
    # @param [Fixnum] num device number
    # @return [Array] of 10 free devices
    def FreeAliases(type, num)
      # FIXME: NI y2debug("Devices=%1", Devices);
      _Devices_1 = {} # FIXME: NI Devices[type, sformat("%1",num)]:$[];
      Builtins.y2debug("Devices=%1", _Devices_1)
      NetworkInterfaces.GetFreeDevices("_aliases", 10)
    end


    # must be in sync with {#SetDefaultsForHW}
    def GetDefaultsForHW
      ret = {}
      if @type == "wlan"
        ret = Builtins.union(
          ret, # #63767
          { "USERCONTROL" => "yes" }
        )
      # LCS eth interfaces on s390 need the MTU of 1492. #81815.
      # TODO: lcs, or eth?
      # will eth not get mapped to lcs?
      # Apparently both LCS eth and LCS tr are represented as "lcs"
      # but it does not hurt to change the default also for tr
      # #93798: limit to s390 to minimize regressions. Probably it could
      # be also done by only testing for lcs and not eth but that
      # would need more testing.
      elsif Arch.s390 && Builtins.contains(["lcs", "eth"], @type)
        Builtins.y2milestone("Adding LCS: setting MTU")
        ret = Builtins.add(ret, "MTU", "1492")
      end
      deep_copy(ret)
    end

    # must be in sync with {#GetDefaultsForHW}
    def SetDefaultsForHW
      Builtins.y2milestone("SetDefaultsForHW type %1", @type)
      if @type == "wlan"
        @usercontrol = true
      elsif Arch.s390 && Builtins.contains(["lcs", "eth"], @type)
        @mtu = "1492"
      end 
      # if (!needHwcfg(hw)){
      # 		nm_name_old = nm_name;
      # 		nm_name = "";
      # 	}
      # y2milestone("hwcfg name %1", nm_name);

      nil
    end

    def GetDeviceVar(primary, fallback, key)
      primary = deep_copy(primary)
      fallback = deep_copy(fallback)
      ret = Ops.get_string(primary, key, Ops.get(fallback, key))
      Builtins.y2debug("%1 does not have a default defined", key) if ret == nil
      ret
    end


    # Set various device variables
    # @param [Hash] devmap map with variables
    # @return [void]
    def SetDeviceVars(devmap, defaults)
      devmap = deep_copy(devmap)
      defaults = deep_copy(defaults)
      # address options
      @bootproto = GetDeviceVar(devmap, defaults, "BOOTPROTO")
      @ipaddr = GetDeviceVar(devmap, defaults, "IPADDR")
      @prefix = GetDeviceVar(devmap, defaults, "PREFIXLEN")
      @remoteip = GetDeviceVar(devmap, defaults, "REMOTE_IPADDR")
      @netmask = GetDeviceVar(devmap, defaults, "NETMASK")

      @mtu = GetDeviceVar(devmap, defaults, "MTU")
      @ethtool_options = GetDeviceVar(devmap, defaults, "ETHTOOL_OPTIONS")
      @startmode = GetDeviceVar(devmap, defaults, "STARTMODE")
      @ifplugd_priority = GetDeviceVar(devmap, defaults, "IFPLUGD_PRIORITY")
      @usercontrol = GetDeviceVar(devmap, defaults, "USERCONTROL") == "yes"
      @description = GetDeviceVar(devmap, defaults, "NAME")
      @bond_option = GetDeviceVar(devmap, defaults, "BONDING_MODULE_OPTS")
      @vlan_etherdevice = GetDeviceVar(devmap, defaults, "ETHERDEVICE")
      @vlan_id = GetDeviceVar(devmap, defaults, "VLAN_ID") # FIXME, remember that it can be implied from the name. probably

      @bridge_ports = GetDeviceVar(devmap, defaults, "BRIDGE_PORTS")

      @bond_slaves = []
      Builtins.foreach(devmap) do |key, value|
        if Builtins.regexpmatch(Convert.to_string(key), "BONDING_SLAVE[0-9]+")
          if Convert.to_string(value) != nil
            @bond_slaves = Builtins.add(@bond_slaves, Convert.to_string(value))
          end
        end
      end

      # tun/tap settings
      @tunnel_set_owner = GetDeviceVar(devmap, defaults, "TUNNEL_SET_OWNER")
      @tunnel_set_group = GetDeviceVar(devmap, defaults, "TUNNEL_SET_GROUP")
      @tunnel_set_persistent = GetDeviceVar(
        devmap,
        defaults,
        "TUNNEL_SET_PERSISTENT"
      ) == "yes"

      # wireless options
      @wl_mode = GetDeviceVar(devmap, defaults, "WIRELESS_MODE")
      @wl_essid = GetDeviceVar(devmap, defaults, "WIRELESS_ESSID")
      @wl_nwid = GetDeviceVar(devmap, defaults, "WIRELESS_NWID")
      @wl_auth_mode = GetDeviceVar(devmap, defaults, "WIRELESS_AUTH_MODE")
      @wl_wpa_psk = GetDeviceVar(devmap, defaults, "WIRELESS_WPA_PSK")
      @wl_key_length = GetDeviceVar(devmap, defaults, "WIRELESS_KEY_LENGTH")
      @wl_key = [] # ensure exactly 4 entries
      Ops.set(@wl_key, 0, GetDeviceVar(devmap, defaults, "WIRELESS_KEY_0"))
      if Ops.get(@wl_key, 0, "") == ""
        Ops.set(@wl_key, 0, GetDeviceVar(devmap, defaults, "WIRELESS_KEY"))
      end
      Ops.set(@wl_key, 1, GetDeviceVar(devmap, defaults, "WIRELESS_KEY_1"))
      Ops.set(@wl_key, 2, GetDeviceVar(devmap, defaults, "WIRELESS_KEY_2"))
      Ops.set(@wl_key, 3, GetDeviceVar(devmap, defaults, "WIRELESS_KEY_3"))

      @wl_default_key = Builtins.tointeger(
        GetDeviceVar(devmap, defaults, "WIRELESS_DEFAULT_KEY")
      )
      @wl_nick = GetDeviceVar(devmap, defaults, "WIRELESS_NICK")

      @wl_wpa_eap = {}
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_MODE",
        GetDeviceVar(devmap, defaults, "WIRELESS_EAP_MODE")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_IDENTITY",
        GetDeviceVar(devmap, defaults, "WIRELESS_WPA_IDENTITY")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_PASSWORD",
        GetDeviceVar(devmap, defaults, "WIRELESS_WPA_PASSWORD")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_ANONID",
        GetDeviceVar(devmap, defaults, "WIRELESS_WPA_ANONID")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_CLIENT_CERT",
        GetDeviceVar(devmap, defaults, "WIRELESS_CLIENT_CERT")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_CLIENT_KEY",
        GetDeviceVar(devmap, defaults, "WIRELESS_CLIENT_KEY")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_CLIENT_KEY_PASSWORD",
        GetDeviceVar(devmap, defaults, "WIRELESS_CLIENT_KEY_PASSWORD")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_CA_CERT",
        GetDeviceVar(devmap, defaults, "WIRELESS_CA_CERT")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_AUTH",
        GetDeviceVar(devmap, defaults, "WIRELESS_EAP_AUTH")
      )
      Ops.set(
        @wl_wpa_eap,
        "WPA_EAP_PEAP_VERSION",
        GetDeviceVar(devmap, defaults, "WIRELESS_PEAP_VERSION")
      )

      @wl_channel = GetDeviceVar(devmap, defaults, "WIRELESS_CHANNEL")
      @wl_frequency = GetDeviceVar(devmap, defaults, "WIRELESS_FREQUENCY")
      @wl_bitrate = GetDeviceVar(devmap, defaults, "WIRELESS_BITRATE")
      @wl_accesspoint = GetDeviceVar(devmap, defaults, "WIRELESS_AP")
      @wl_power = GetDeviceVar(devmap, defaults, "WIRELESS_POWER") == "yes"
      @wl_ap_scanmode = GetDeviceVar(devmap, defaults, "WIRELESS_AP_SCANMODE")
      # s/390 options
      # We always have to set the MAC Address for qeth Layer2 support
      @qeth_macaddress = GetDeviceVar(devmap, defaults, "LLADDR")

      @aliases = Ops.get_map(devmap, "_aliases", {})

      nil
    end

    # Initializes s390 specific device variables.
    #
    # @param [Hash] devmap    map with s390 specific attributes and its values
    # @param [Hash] defaults  map with default values for attributes not found in devmap
    def SetS390Vars(devmap, defaults)
      devmap = deep_copy(devmap)
      defaults = deep_copy(defaults)
      return if !Arch.s390

      @qeth_portname = GetDeviceVar(devmap, defaults, "QETH_PORTNAME")
      @qeth_portnumber = GetDeviceVar(devmap, defaults, "QETH_PORTNUMBER")
      @qeth_layer2 = GetDeviceVar(devmap, defaults, "QETH_LAYER2") == "yes"
      @qeth_chanids = GetDeviceVar(devmap, defaults, "QETH_CHANIDS")

      # qeth attribute. FIXME: currently not read from system.
      @ipa_takeover = Ops.get_string(defaults, "IPA_TAKEOVER", "") == "yes"

      # not device attribute
      @qeth_options = Ops.get_string(defaults, "QETH_OPTIONS", "")

      # handle non qeth devices
      @iucv_user = Ops.get_string(defaults, "IUCV_USER", "")
      @chan_mode = Ops.get_string(defaults, "CHAN_MODE", "")

      nil
    end

    def InitS390VarsByDefaults
      SetS390Vars({}, @s390_defaults)

      nil
    end

    # Select the given device
    # @param [String] dev device to select ("" for new device, default values)
    # @return true if success
    def Select(dev)
      Builtins.y2debug("dev=%1", dev)
      devmap = {}
      # defaults for a new device
      devmap = {
        # for hotplug devices set STARTMODE=hotplug (#132583)
        "STARTMODE" => IsNotEmpty(
          Ops.get_string(@Items, [@current, "hwinfo", "hotplug"], "")
        ) ? "hotplug" : "auto", # #115448, #156388
        "NETMASK"   => Ops.get_string(
          NetHwDetection.result,
          "NETMASK",
          "255.255.255.0"
        )
      } # #31369
      product_startmode = ProductFeatures.GetStringFeature(
        "network",
        "startmode"
      )
      if Builtins.contains(["auto", "ifplugd"], product_startmode)
        Builtins.y2milestone("Product startmode: %1", product_startmode)
        if product_startmode == "ifplugd" && !Arch.is_laptop
          # #164816
          Builtins.y2milestone("Not a laptop, will not prefer ifplugd")
          product_startmode = IsNotEmpty(
            Ops.get_string(@Items, [@current, "hwinfo", "hotplug"], "")
          ) ? "hotplug" : "auto"
        end
        if product_startmode == "ifplugd" && NetworkService.IsManaged
          Builtins.y2milestone("For NetworkManager will not prefer ifplugd")
          product_startmode = IsNotEmpty(
            Ops.get_string(@Items, [@current, "hwinfo", "hotplug"], "")
          ) ? "hotplug" : "auto"
        end
        if product_startmode == "ifplugd" &&
            Builtins.contains(["bond", "vlan", "br"], @type)
          Builtins.y2milestone(
            "For virtual networktypes (bond, bridge, vlan) will not prefer ifplugd"
          )
          product_startmode = IsNotEmpty(
            Ops.get_string(@Items, [@current, "hwinfo", "hotplug"], "")
          ) ? "hotplug" : "auto"
        end
        Ops.set(devmap, "STARTMODE", product_startmode)
      end

      @type = Ops.get_string(@Items, [@current, "hwinfo", "type"], "eth")
      @device = NetworkInterfaces.GetFreeDevice(@type)

      # TODO: instead of udev use hwinfo dev_name
      NetworkInterfaces.Name = GetItemUdev("NAME")
      if Ops.less_than(Builtins.size(@Items), @current)
        Ops.set(@Items, @current, { "ifcfg" => NetworkInterfaces.Name })
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

      # We always have to set the MAC Address for qeth Layer2 support
      if @qeth_layer2
        @qeth_macaddress = Ops.get_string(devmap, "LLADDR", "00:00:00:00:00:00")
      end

      true
    end

    # Commit pending operation
    # @return true if success
    def Commit
      if @operation == :add || @operation == :edit
        newdev = {}

        # #104494 - always write IPADDR+NETMASK, even empty
        Ops.set(newdev, "IPADDR", @ipaddr)
        if Ops.greater_than(Builtins.size(@prefix), 0)
          Ops.set(newdev, "PREFIXLEN", @prefix)
        else
          Ops.set(newdev, "NETMASK", @netmask)
        end
        # #50955 omit computable fields
        Ops.set(newdev, "BROADCAST", "")
        Ops.set(newdev, "NETWORK", "")

        Ops.set(newdev, "REMOTE_IPADDR", @remoteip)

        # set LLADDR to sysconfig only for device on layer2 and only these which needs it
        if @qeth_layer2
          busid = Ops.get_string(@Items, [@current, "hwinfo", "busid"], "")
          # string sysfs_id = busid_to_sysfs_id(busid, Hardware);
          # sysfs id has changed from css0...
          sysfs_id = Ops.add("/devices/qeth/", busid)
          Builtins.y2milestone("busid %1", busid)
          if s390_device_needs_persistent_mac(sysfs_id, @Hardware)
            Ops.set(newdev, "LLADDR", @qeth_macaddress)
          end
        end

        if @alias == ""
          Ops.set(newdev, "MTU", @mtu)
          Ops.set(newdev, "ETHTOOL_OPTIONS", @ethtool_options)
          Ops.set(newdev, "STARTMODE", @startmode)
          # it is not in Select yet because we don't have a widget for it
          if @startmode == "ifplugd"
            if @ifplugd_priority != nil
              Ops.set(newdev, "IFPLUGD_PRIORITY", @ifplugd_priority)
            else
              Ops.set(
                newdev,
                "IFPLUGD_PRIORITY",
                Ops.get(@ifplugd_priorities, @type, "0")
              )
            end
          end
          Ops.set(newdev, "USERCONTROL", @usercontrol ? "yes" : "no")
          Ops.set(newdev, "BOOTPROTO", @bootproto)
        end
        Ops.set(newdev, "NAME", @description)

        Ops.set(newdev, "DHCLIENT_SET_DOWN_LINK", "yes") if @hotplug == "pcmcia"


        if @type == "bond"
          i = 0
          Builtins.foreach(@bond_slaves) do |slave|
            Ops.set(newdev, Builtins.sformat("BONDING_SLAVE%1", i), slave)
            i = Ops.add(i, 1)
          end

          #assign nil to rest BONDING_SLAVEn to remove them
          while Ops.less_than(i, @MAX_BOND_SLAVE)
            Ops.set(newdev, Builtins.sformat("BONDING_SLAVE%1", i), nil)
            i = Ops.add(i, 1)
          end

          Ops.set(newdev, "BONDING_MODULE_OPTS", @bond_option)

          #BONDING_MASTER always is yes
          Ops.set(newdev, "BONDING_MASTER", "yes")
        end

        if @type == "vlan"
          Ops.set(newdev, "ETHERDEVICE", @vlan_etherdevice)
          Ops.set(newdev, "VLAN_ID", @vlan_id)
        end
        if @type == "br"
          Ops.set(newdev, "BRIDGE_PORTS", @bridge_ports)
          Ops.set(newdev, "BRIDGE", "yes")
          Ops.set(newdev, "BRIDGE_STP", "off")
          Ops.set(newdev, "BRIDGE_FORWARDDELAY", "0")
        end

        if @type == "wlan"
          Ops.set(newdev, "WIRELESS_MODE", @wl_mode)
          Ops.set(newdev, "WIRELESS_ESSID", @wl_essid)
          Ops.set(newdev, "WIRELESS_NWID", @wl_nwid)
          Ops.set(newdev, "WIRELESS_AUTH_MODE", @wl_auth_mode)
          Ops.set(newdev, "WIRELESS_WPA_PSK", @wl_wpa_psk)
          Ops.set(newdev, "WIRELESS_KEY_LENGTH", @wl_key_length)
          # obsoleted by WIRELESS_KEY_0
          Ops.set(newdev, "WIRELESS_KEY", "") # TODO: delete the varlable
          Ops.set(newdev, "WIRELESS_KEY_0", Ops.get(@wl_key, 0, ""))
          Ops.set(newdev, "WIRELESS_KEY_1", Ops.get(@wl_key, 1, ""))
          Ops.set(newdev, "WIRELESS_KEY_2", Ops.get(@wl_key, 2, ""))
          Ops.set(newdev, "WIRELESS_KEY_3", Ops.get(@wl_key, 3, ""))
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

          Ops.set(newdev, "WIRELESS_CHANNEL", @wl_channel)
          Ops.set(newdev, "WIRELESS_FREQUENCY", @wl_frequency)
          Ops.set(newdev, "WIRELESS_BITRATE", @wl_bitrate)
          Ops.set(newdev, "WIRELESS_AP", @wl_accesspoint)
          Ops.set(newdev, "WIRELESS_POWER", @wl_power ? "yes" : "no")
        end

        if DriverType(@type) == "ctc"
          if Ops.get(NetworkConfig.Config, "WAIT_FOR_INTERFACES") == nil ||
              Ops.less_than(
                Ops.get_integer(NetworkConfig.Config, "WAIT_FOR_INTERFACES", 0),
                40
              )
            Ops.set(NetworkConfig.Config, "WAIT_FOR_INTERFACES", 40)
          end
        end

        if @alias == ""
          Ops.set(newdev, "_aliases", @aliases)
          Builtins.y2milestone("aliases %1", @aliases)
        end
        if Builtins.contains(["tun", "tap"], @type)
          newdev = {
            "BOOTPROTO"             => "static",
            "STARTMODE"             => "auto",
            "TUNNEL"                => @type,
            "TUNNEL_SET_PERSISTENT" => @tunnel_set_persistent ? "yes" : "no",
            "TUNNEL_SET_OWNER"      => @tunnel_set_owner,
            "TUNNEL_SET_GROUP"      => @tunnel_set_group
          }
        end

        # L3: bnc#585458
        # FIXME: INTERFACETYPE confuses sysconfig, bnc#458412
        # Only test when newdev has enough info for GetTypeFromIfcfg to work.
        implied_type = NetworkInterfaces.GetTypeFromIfcfg(newdev)
        if implied_type != nil && implied_type != @type
          Ops.set(newdev, "INTERFACETYPE", @type)
        end

        NetworkInterfaces.Name = Ops.get_string(@Items, [@current, "ifcfg"], "")
        NetworkInterfaces.Current = deep_copy(newdev)

        # bnc#752464 - can leak wireless passwords
        # useful only for debugging. Writes huge struct mostly filled by defaults.
        Builtins.y2debug("%1", NetworkInterfaces.ConcealSecrets1(newdev))

        Ops.set(@Items, [@current, "ifcfg"], "") if !NetworkInterfaces.Commit
      else
        Builtins.y2error("Unknown operation: %1", @operation)
        return false
      end
      @modified = true
      @operation = nil
      true
    end

    def Rollback
      if Ops.get_boolean(getCurrentItem, "commited", true) == false
        Builtins.y2milestone("rollback item %1", @current)
        if !Ops.greater_than(
            Builtins.size(Ops.get_map(getCurrentItem, "hwinfo", {})),
            0
          )
          @Items = Builtins.remove(@Items, @current)
        else
          if Builtins.haskey(Ops.get_map(@Items, @current, {}), "ifcfg")
            if !Builtins.contains(
                getNetworkInterfaces,
                Ops.get_string(getCurrentItem, "ifcfg", "")
              )
              Ops.set(
                @Items,
                @current,
                Builtins.remove(Ops.get_map(@Items, @current, {}), "ifcfg")
              )
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


    # Find matching device
    # Find a device, optionally with some predefined values
    # @param [Hash] interface interface map
    # @return [Hash] The map of the matching device.
    def FindMatchingDevice(interface)
      interface = deep_copy(interface)
      tosel = nil
      # Minimal changes to code to fix both #119592 and #146965
      # Alternatively we could try to ensure that we never match a
      # device that got already matched
      matched_by_module = false

      devs = NetworkInterfaces.List("netcard")
      Builtins.y2milestone("Configured devices: %1", devs)

      # this condition is always true for SLES9, HEAD uses $[] for proposal
      if interface != {}
        # Notes for comments about matching:
        # - interface["device"] is the key which we look for in the actual hw
        # - H iterates over Hardware
        # - patterns are shell-like

        device_id = Builtins.splitstring(
          Ops.get_string(interface, "device", ""),
          "-"
        )
        # code for eth-id-00:80:c8:f6:48:4c configurations
        # *-id-$ID => find H["mac"] == $ID
        if Ops.greater_than(Builtins.size(device_id), 1) &&
            Ops.get_string(device_id, 1, "") == "id"
          hwaddr = Ops.get_string(device_id, 2, "")
          tosel = Builtins.find(@Hardware) do |h|
            Ops.get_string(h, "mac", "") == hwaddr
          end if hwaddr != nil &&
            hwaddr != ""
          Builtins.y2milestone("Rule: matching mac in device name")
        # code for eth-bus-pci-0000:00:0d.0 configurations
        # code for eth-bus-vio-30000001 configurations
        # *-bus-$BUS-$ID => find H["bus"] == $BUS & H["busid"] == $ID
        elsif Ops.greater_than(Builtins.size(device_id), 2) &&
            Ops.get_string(device_id, 1, "") == "bus"
          bus = Ops.get_string(device_id, 2, "")
          busid = Ops.get_string(device_id, 3, "")
          if bus != nil && bus != "" && busid != nil && busid != ""
            tosel = Builtins.find(@Hardware) do |h|
              Ops.get_string(h, "busid", "") == busid &&
                Ops.get_string(h, "bus", "") == bus
            end
          end
          Builtins.y2milestone("Rule: matching bus id in device name")
        end

        # code for module configuration
        # join with the modules list of the ay profile according to "device"
        # if exists => find H["module"] == AH["module"]
        aymodule = GetModuleForInterface(
          Ops.get_string(interface, "device", ""),
          Ops.get_list(@autoinstall_settings, "modules", [])
        )
        Builtins.y2milestone("module data: %1", aymodule)
        if tosel == nil && aymodule != {}
          if aymodule != nil && Ops.get_string(aymodule, "module", "") != ""
            tosel = Builtins.find(@Hardware) do |h|
              Ops.get_string(h, "module", "") ==
                Ops.get_string(aymodule, "module", "")
            end
          end
          matched_by_module = true if tosel != nil
          Builtins.y2milestone("Rule: matching module configuration")
        end
      end

      # First device was already configured, we are now looking for
      # a second (third,...) one
      if Ops.greater_than(Builtins.size(devs), 0)
        # #119592, #146965: this used to be unconditional, overwriting the
        # results of the above matching.
        if matched_by_module || tosel == nil
          # go thru all devices, check whether there's one that does
          # not have a configuration yet
          # and has the same type as the current profile item
          Builtins.foreach(@Hardware) do |h|
            Builtins.y2milestone("Checking for device=%1", h)
            SelectHWMap(h)
            #		string _device_name = NetworkInterfaces::device_name(NetworkInterfaces::RealType(type, hotplug), device);
            if !NetworkInterfaces.Check(@device) &&
                @type ==
                  NetworkInterfaces.GetType(
                    Ops.get_string(interface, "device", "")
                  )
              Builtins.y2milestone("Selected: %1", h)
              tosel = deep_copy(h)
              raise Break
            end
          end
        end
        Builtins.y2error("Nothing found") if tosel == nil
      else
        # this is the first interface, match the hardware with install.inf
        # No install.inf -> select the first connected
        # find H["active"] == true
        if tosel == nil
          tosel = Builtins.find(@Hardware) do |h|
            Ops.get_boolean(h, ["link", "state"], false)
          end
          Builtins.y2milestone("Rule: first connected")
        end

        # No install.inf driver -> select the first active
        # find H["active"] == true
        if tosel == nil
          tosel = Builtins.find(@Hardware) do |h|
            Ops.get_boolean(h, "active", false)
          end
          Builtins.y2milestone("Rule: first active")
        end

        # No active driver -> select the first with a driver
        # find H["module"] != ""
        if tosel == nil
          Builtins.y2milestone("No active driver found, trying further.")
          tosel = Builtins.find(@Hardware) do |h|
            Ops.get_string(h, "module", "") != "" &&
              Builtins.y2milestone("Using driver: %1", h) == nil
          end
          Builtins.y2milestone("Rule: first with driver")
        end
      end

      deep_copy(tosel)
    end

    def DeleteItem
      Builtins.y2milestone("deleting ... %1", Ops.get_map(@Items, @current, {}))
      ifcfg = Ops.get_string(@Items, [@current, "ifcfg"], "")
      hwcfg = Ops.get_string(@Items, [@current, "hwcfg"], "")

      if IsNotEmpty(ifcfg)
        NetworkInterfaces.Delete(ifcfg)
        NetworkInterfaces.Commit
        Ops.set(@Items, [@current, "ifcfg"], "")
      end
      if !Ops.greater_than(
          Builtins.size(Ops.get_map(@Items, [@current, "hwinfo"], {})),
          0
        )
        tmp_items = {}
        Builtins.foreach(@Items) do |key, value|
          if key == @current
            next
          else
            if Ops.less_than(key, @current)
              Ops.set(tmp_items, key, Ops.get_map(@Items, key, {}))
            else
              Ops.set(
                tmp_items,
                Ops.subtract(key, 1),
                Ops.get_map(@Items, key, {})
              )
            end
          end
        end
        @Items = deep_copy(tmp_items)
      end
      SetModified()

      nil
    end

    def SetItem
      @operation = :edit
      @device = Ops.get_string(getCurrentItem, "ifcfg", "")
      @interfacename = @device

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
      if NetworkStorage.isDiskOnNetwork(NetworkStorage.getDevice("/")) != :no
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

    def createS390Device
      Builtins.y2milestone("creating device s390 network device")
      result = true
      # command to create device
      command1 = ""
      # command to find created device
      command2 = ""
      case @type
        when "hsi", "qeth"
          @portnumber_param = Ops.greater_than(
            Builtins.size(@qeth_portnumber),
            0
          ) ?
            Builtins.sformat("-n %1", @qeth_portnumber) :
            ""
          @portname_param = Ops.greater_than(Builtins.size(@qeth_portname), 0) ?
            Builtins.sformat("-p %1", @qeth_portname) :
            ""
          @options_param = Ops.greater_than(Builtins.size(@qeth_options), 0) ?
            Builtins.sformat("-o %1", @qeth_options) :
            ""
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
        :from => "any",
        :to   => "map <string, any>"
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
          :from => "any",
          :to   => "map <string, any>"
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

    publish :variable => :Items, :type => "map <integer, any>"
    publish :variable => :Hardware, :type => "list <map>"
    publish :variable => :udev_net_rules, :type => "map <string, any>"
    publish :variable => :driver_options, :type => "map <string, any>"
    publish :variable => :interfacename, :type => "string"
    publish :variable => :autoinstall_settings, :type => "map"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :operation, :type => "symbol"
    publish :variable => :force_restart, :type => "boolean"
    publish :variable => :description, :type => "string"
    publish :variable => :type, :type => "string"
    publish :variable => :device, :type => "string"
    publish :variable => :alias, :type => "string"
    publish :variable => :current, :type => "integer"
    publish :variable => :hotplug, :type => "string"
    publish :variable => :Requires, :type => "list <string>"
    publish :variable => :bootproto, :type => "string"
    publish :variable => :ipaddr, :type => "string"
    publish :variable => :remoteip, :type => "string"
    publish :variable => :netmask, :type => "string"
    publish :variable => :prefix, :type => "string"
    publish :variable => :startmode, :type => "string"
    publish :variable => :ifplugd_priority, :type => "string"
    publish :variable => :usercontrol, :type => "boolean"
    publish :variable => :mtu, :type => "string"
    publish :variable => :ethtool_options, :type => "string"
    publish :variable => :wl_mode, :type => "string"
    publish :variable => :wl_essid, :type => "string"
    publish :variable => :wl_nwid, :type => "string"
    publish :variable => :wl_auth_mode, :type => "string"
    publish :variable => :wl_wpa_psk, :type => "string"
    publish :variable => :wl_key_length, :type => "string"
    publish :variable => :wl_key, :type => "list <string>"
    publish :variable => :wl_default_key, :type => "integer"
    publish :variable => :wl_nick, :type => "string"
    publish :variable => :bond_slaves, :type => "list <string>"
    publish :variable => :bond_option, :type => "string"
    publish :variable => :vlan_etherdevice, :type => "string"
    publish :variable => :vlan_id, :type => "string"
    publish :variable => :bridge_ports, :type => "string"
    publish :variable => :wl_wpa_eap, :type => "map <string, any>"
    publish :variable => :wl_channel, :type => "string"
    publish :variable => :wl_frequency, :type => "string"
    publish :variable => :wl_bitrate, :type => "string"
    publish :variable => :wl_accesspoint, :type => "string"
    publish :variable => :wl_power, :type => "boolean"
    publish :variable => :wl_ap_scanmode, :type => "string"
    publish :variable => :wl_auth_modes, :type => "list <string>"
    publish :variable => :wl_enc_modes, :type => "list <string>"
    publish :variable => :wl_channels, :type => "list <string>"
    publish :variable => :wl_bitrates, :type => "list <string>"
    publish :variable => :qeth_portname, :type => "string"
    publish :variable => :qeth_portnumber, :type => "string"
    publish :variable => :chan_mode, :type => "string"
    publish :variable => :qeth_options, :type => "string"
    publish :variable => :ipa_takeover, :type => "boolean"
    publish :variable => :iucv_user, :type => "string"
    publish :variable => :qeth_layer2, :type => "boolean"
    publish :variable => :qeth_macaddress, :type => "string"
    publish :variable => :qeth_chanids, :type => "string"
    publish :variable => :lcs_timeout, :type => "string"
    publish :variable => :aliases, :type => "map"
    publish :variable => :tunnel_set_persistent, :type => "boolean"
    publish :variable => :tunnel_set_owner, :type => "string"
    publish :variable => :tunnel_set_group, :type => "string"
    publish :variable => :proposal_valid, :type => "boolean"
    publish :variable => :nm_proposal_valid, :type => "boolean"
    publish :variable => :nm_name, :type => "string"
    publish :variable => :nm_name_old, :type => "string"
    publish :function => :GetLanItem, :type => "map (integer)"
    publish :function => :getCurrentItem, :type => "map ()"
    publish :function => :IsItemConfigured, :type => "boolean (integer)"
    publish :function => :IsCurrentConfigured, :type => "boolean ()"
    publish :function => :GetDeviceName, :type => "string (integer)"
    publish :function => :GetCurrentName, :type => "string ()"
    publish :function => :GetDeviceType, :type => "string (integer)"
    publish :function => :GetDeviceMap, :type => "map <string, any> (integer)"
    publish :function => :GetItemUdevRule, :type => "list <string> (integer)"
    publish :function => :GetItemUdev, :type => "string (string)"
    publish :function => :ReplaceItemUdev, :type => "list <string> (string, string, string)"
    publish :function => :SetItemUdev, :type => "list <string> (string, string)"
    publish :function => :WriteUdevRules, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :UnsetModified, :type => "void ()"
    publish :function => :AddNew, :type => "void ()"
    publish :function => :GetItemModules, :type => "list <string> (string)"
    publish :function => :GetSlaveCandidates, :type => "list <integer> (string, boolean (string, integer))"
    publish :function => :GetBondableInterfaces, :type => "list <integer> (string)"
    publish :function => :GetBridgeableInterfaces, :type => "list <integer> (string)"
    publish :function => :FindAndSelect, :type => "boolean (string)"
    publish :function => :FindDeviceIndex, :type => "integer (string)"
    publish :function => :ReadHw, :type => "void ()"
    publish :function => :Read, :type => "void ()"
    publish :function => :needFirmwareCurrentItem, :type => "boolean ()"
    publish :function => :GetFirmwareForCurrentItem, :type => "string ()"
    publish :function => :GetBondSlaves, :type => "list <string> (string)"
    publish :function => :BuildLanOverview, :type => "list ()"
    publish :function => :Overview, :type => "list ()"
    publish :function => :isCurrentHotplug, :type => "boolean ()"
    publish :function => :isCurrentDHCP, :type => "boolean ()"
    publish :function => :GetItemDescription, :type => "string ()"
    publish :function => :InterfaceHasAliases, :type => "boolean ()"
    publish :function => :SelectHWMap, :type => "void (map)"
    publish :function => :SelectHW, :type => "void (integer)"
    publish :function => :FreeDevices, :type => "list (string)"
    publish :function => :FreeAliases, :type => "list (string, integer)"
    publish :function => :GetDefaultsForHW, :type => "map ()"
    publish :function => :SetDefaultsForHW, :type => "void ()"
    publish :function => :SetDeviceVars, :type => "void (map, map)"
    publish :variable => :SysconfigDefaults, :type => "map <string, string>"
    publish :function => :Select, :type => "boolean (string)"
    publish :function => :Commit, :type => "boolean ()"
    publish :function => :Rollback, :type => "boolean ()"
    publish :function => :GetModuleForInterface, :type => "map (string, list <map>)"
    publish :function => :FindMatchingDevice, :type => "map (map)"
    publish :function => :DeleteItem, :type => "void ()"
    publish :function => :SetItem, :type => "void ()"
    publish :function => :ProposeItem, :type => "boolean ()"
    publish :function => :setDriver, :type => "void (string)"
    publish :function => :enableCurrentEditButton, :type => "boolean ()"
    publish :function => :createS390Device, :type => "boolean ()"
  end

  LanItems = LanItemsClass.new
  LanItems.main
end
