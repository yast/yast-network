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
require "network/network_autoyast"
require "network/install_inf_convertor"
require "network/wicked"
require "network/lan_items_summary"
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

      # in special cases when rcnetwork reload is not enought
      @force_restart = false

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

    # Return the current device names
    #
    # @ return [Array<String>]
    def current_device_names
      GetNetcardInterfaces().map { |i| current_name_for(i) }.reject(&:empty?)
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
        hw_dev_mac = hw["permanent_mac"] || hw["mac"] || ""
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
      NetworkAutoYast.instance.activate_s390_devices(settings.fetch("s390-devices", {})) if Arch.s390

      # settings == {} has special meaning 'Reset' used by AY
      SetModified() if !settings.empty?

      true
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

    def SetItem(*)
      @hotplug = ""
      Builtins.y2debug("type=%1", @type)
      if Builtins.issubstring(@type, "-")
        @type = Builtins.regexpsub(@type, "([^-]+)-.*$", "\\1")
      end
      Builtins.y2debug("type=%1", @type)

      nil
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
        @options_param = if Ops.greater_than(Builtins.size(@qeth_options), 0)
          Builtins.sformat("-o %1", @qeth_options.shellescape)
        else
          ""
        end
        command1 = Builtins.sformat(
          "/sbin/qeth_configure %1 %2 %3 %4 %5 1",
          @options_param,
          @qeth_layer2 ? "-l" : "",
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
    publish function: :ReadHw, type: "void ()"
    publish function: :Read, type: "void ()"
    publish function: :isCurrentHotplug, type: "boolean ()"
    publish function: :isCurrentDHCP, type: "boolean ()"
    publish function: :Commit, type: "boolean ()"
    publish function: :createS390Device, type: "boolean ()"
    publish function: :find_dhcp_ifaces, type: "list <string> ()"
  end

  LanItems = LanItemsClass.new
  LanItems.main
end
