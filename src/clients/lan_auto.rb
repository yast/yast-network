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

require "network/network_autoyast"

module Yast
  # Client providing autoyast functionality
  class LanAutoClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Lan autoinst client started")

      Yast.import "Lan"
      Yast.import "Progress"
      Yast.import "Map"
      Yast.import "NetworkInterfaces"
      Yast.import "LanItems"
      Yast.include self, "network/lan/wizards.rb"
      Yast.include self, "network/routines.rb"

      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2milestone("Lan autoinst callback: #{@func}")

      if @func == "Summary"
        @ret = Ops.get_string(Lan.Summary("summary"), 0, "")
      elsif @func == "Reset"
        Lan.Import({})
        @ret = {}
      elsif @func == "Change"
        @ret = LanAutoSequence("")
      elsif @func == "Import"
        @new = FromAY(@param)
        # see bnc#498993
        # in case keep_install_network is set to true (in AY)
        # we'll keep values from installation
        # and merge with XML data (bnc#712864)
        @new = NetworkAutoYast.instance.merge_configs(@new) if @new["keep_install_network"]

        Lan.Import(@new)
        @ret = true
      elsif @func == "Read"
        @progress_orig = Progress.set(false)
        @ret = Lan.Read(:nocache)
        Progress.set(@progress_orig)
      elsif @func == "Packages"
        @ret = Lan.AutoPackages
      elsif @func == "SetModified"
        @ret = LanItems.SetModified
      elsif @func == "GetModified"
        @ret = LanItems.GetModified
      elsif @func == "Export"
        @settings2 = Lan.Export
        Builtins.y2debug("settings: %1", @settings2)
        @autoyast = ToAY(@settings2)
        @ret = deep_copy(@autoyast)
      elsif @func == "Write"
        @progress_orig = Progress.set(false)

        result = Lan.WriteOnly
        Builtins.y2error("Writing lan config failed") if !result
        @ret &&= result

        if Ops.get(LanItems.autoinstall_settings, "strict_IP_check_timeout")
          if Lan.isAnyInterfaceDown
            @timeout = Ops.get_integer(
              LanItems.autoinstall_settings,
              "strict_IP_check_timeout",
              0
            )
            Builtins.y2debug("timeout %1", @timeout)
            @error_text = _("Configuration Error: uninitialized interface.")
            if @timeout == 0
              Popup.Error(@error_text)
            else
              Popup.TimedError(@error_text, @timeout)
            end
          end
        end
        Progress.set(@progress_orig)
      else
        Builtins.y2error("unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2milestone("Lan auto finished (#{@ret})")
      Builtins.y2milestone("----------------------------------------")
      @ret
    end

    # If there's key in m, upcase key and assign the value to ret
    # @return ret
    def UpcaseCondSet(ret, m, key)
      ret = deep_copy(ret)
      m = deep_copy(m)
      if Builtins.haskey(m, key)
        Ops.set(ret, Builtins.toupper(key), Ops.get(m, key))
      end
      deep_copy(ret)
    end

    # Convert data from autoyast to structure used by module.
    # @param [Hash] input autoyast settings
    # @return native network settings
    def FromAY(input)
      input = deep_copy(input)
      Builtins.y2debug("input %1", input)

      ifaces = []
      Builtins.foreach(Ops.get_list(input, "interfaces", [])) do |interface|
        iface = {}
        Builtins.foreach(interface) do |key, value|
          if key == "aliases"
            Builtins.foreach(
              Convert.convert(
                value,
                from: "any",
                to:   "map <string, map <string, any>>"
              )
            ) do |k, v|
              # replace "alias0" to "0" (bnc#372687)
              t = Convert.convert(
                value,
                from: "any",
                to:   "map <string, any>"
              )
              Ops.set(t, Ops.get_string(v, "LABEL", ""), Ops.get_map(t, k, {}))
              t = Builtins.remove(t, k)
              value = deep_copy(t)
            end
          end
          Ops.set(iface, key, value)
        end
        ifaces = Builtins.add(ifaces, iface)
      end
      Ops.set(input, "interfaces", ifaces)

      interfaces = Builtins.listmap(Ops.get_list(input, "interfaces", [])) do |interface|
        # input: list of items $[ "device": "d", "foo": "f", "bar": "b"]
        # output: map of items  "d": $["FOO": "f", "BAR": "b"]
        new_interface = {}
        # uppercase map keys
        newk = nil
        interface = Builtins.mapmap(interface) do |k, v|
          if k == "aliases"
            newk = "_aliases"
          else
            newk = Builtins.toupper(k)
          end
          { newk => v }
        end
        Builtins.foreach(interface) do |k, v|
          Ops.set(new_interface, k, v) if v != "" && k != "DEVICE"
        end
        new_device = Ops.get_string(interface, "DEVICE", "")
        { new_device => new_interface }
      end

      # split to a two level map like NetworkInterfaces
      devices = {}

      Builtins.foreach(interfaces) do |devname, if_data|
        # devname can be in old-style fashion (eth-bus-<pci_id>). So, convert it
        devname = LanItems.getDeviceName(devname)
        type = NetworkInterfaces.GetType(devname)
        d = Ops.get(devices, type, {})
        Ops.set(d, devname, if_data)
        Ops.set(devices, type, d)
      end

      hwcfg = {}
      if Ops.greater_than(Builtins.size(Ops.get_list(input, "modules", [])), 0)
        hwcfg = Builtins.listmap(Ops.get_list(input, "modules", [])) do |mod|
          options = Ops.get_string(mod, "options", "")
          module_name = Ops.get_string(mod, "module", "")
          start_mode = Ops.get_string(mod, "startmode", "auto")
          device_name = Ops.get_string(mod, "device", "")
          module_data = {
            "MODULE"         => module_name,
            "MODULE_OPTIONS" => options,
            "STARTMODE"      => start_mode
          }
          { device_name => module_data }
        end
      end

      Ops.set(input, "devices", devices)
      Ops.set(input, "hwcfg", hwcfg)

      # DHCP:: config: some of it is in the DNS part of the profile
      dhcp = {}
      dhcpopts = Ops.get_map(input, "dhcp_options", {})
      dns = Ops.get_map(input, "dns", {})

      if Builtins.haskey(dns, "dhcp_hostname")
        Ops.set(
          dhcp,
          "DHCLIENT_SET_HOSTNAME",
          Ops.get_boolean(dns, "dhcp_hostname", false)
        )
      end

      dhcp = UpcaseCondSet(dhcp, dhcpopts, "dhclient_client_id")
      dhcp = UpcaseCondSet(dhcp, dhcpopts, "dhclient_additional_options")
      dhcp = UpcaseCondSet(dhcp, dhcpopts, "dhclient_hostname_option")

      Ops.set(input, "config", "dhcp" => dhcp)
      if !Ops.get(input, "strict_IP_check_timeout").nil?
        Ops.set(input, ["config", "config"], "CHECK_DUPLICATE_IP" => true)
      end

      Builtins.y2milestone("input=%1", input)
      deep_copy(input)
    end

    # Convert data from native network to autoyast for XML
    # @param [Hash] settings native network settings
    # @return [Hash] autoyast network settings
    def ToAY(settings)
      settings = deep_copy(settings)
      interfaces = []
      discard = ["UDI", "_nm_name"]
      Builtins.foreach(Ops.get_map(settings, "devices", {})) do |_type, devsmap|
        Builtins.foreach(
          Convert.convert(devsmap, from: "map", to: "map <string, map>")
        ) do |device, devmap|
          newmap = {}
          Builtins.foreach(
            Convert.convert(devmap, from: "map", to: "map <string, any>")
          ) do |key, val|
            Builtins.y2milestone("Adding: %1=%2", key, val)
            if key != "_aliases"
              if Ops.greater_than(Builtins.size(Convert.to_string(val)), 0) &&
                  !Builtins.contains(discard, key) &&
                  !Builtins.contains(discard, Builtins.tolower(key))
                Ops.set(newmap, Builtins.tolower(key), Convert.to_string(val))
              end
            else
              # handle aliases
              Builtins.y2debug("val: %1", val)
              # if aliases are empty, then ommit it
              if Ops.greater_than(Builtins.size(Convert.to_map(val)), 0)
                # replace key "0" into "alias0" (bnc#372678)
                Builtins.foreach(
                  Convert.convert(
                    val,
                    from: "any",
                    to:   "map <string, map <string, any>>"
                  )
                ) do |k, v|
                  Ops.set(
                    newmap,
                    Builtins.tolower("aliases"),
                    Builtins.add(
                      Ops.get_map(newmap, Builtins.tolower("aliases"), {}),
                      Builtins.sformat("alias%1", k),
                      v
                    )
                  )
                end
              end
            end
          end
          if Builtins.deletechars(device, "0123456789") == ""
            Ops.set(newmap, "device", device)
          else
            Ops.set(newmap, "device", device)
          end
          interfaces = Builtins.add(interfaces, newmap)
        end
      end

      # Modules

      s390_devices = []
      Builtins.foreach(Ops.get_map(settings, "s390-devices", {})) do |_device, mod|
        s390_devices = Builtins.add(s390_devices, mod)
      end

      net_udev = []
      Builtins.foreach(Ops.get_map(settings, "net-udev", {})) do |_device, mod|
        net_udev = Builtins.add(net_udev, mod)
      end

      modules = []
      Builtins.foreach(Ops.get_map(settings, "hwcfg", {})) do |device, mod|
        newmap = {}
        Ops.set(newmap, "device", device)
        Ops.set(newmap, "module", Ops.get_string(mod, "MODULE", ""))
        Ops.set(newmap, "options", Ops.get_string(mod, "MODULE_OPTIONS", ""))
        modules = Builtins.add(modules, newmap)
      end

      config = Ops.get_map(settings, "config", {})
      dhcp = Ops.get_map(config, "dhcp", {})
      dhcp_hostname = Ops.get_boolean(dhcp, "DHCLIENT_SET_HOSTNAME", false)
      dns = Ops.get_map(settings, "dns", {})
      Ops.set(dns, "dhcp_hostname", dhcp_hostname)
      dhcpopts = {}
      if Builtins.haskey(dhcp, "DHCLIENT_HOSTNAME_OPTION")
        Ops.set(
          dhcpopts,
          "dhclient_hostname_option",
          Ops.get_string(dhcp, "DHCLIENT_HOSTNAME_OPTION", "AUTO")
        )
      end
      if Builtins.haskey(dhcp, "DHCLIENT_ADDITIONAL_OPTIONS")
        Ops.set(
          dhcpopts,
          "dhclient_additional_options",
          Ops.get_string(dhcp, "DHCLIENT_ADDITIONAL_OPTIONS", "")
        )
      end
      if Builtins.haskey(dhcp, "DHCLIENT_CLIENT_ID")
        Ops.set(
          dhcpopts,
          "dhclient_client_id",
          Ops.get_string(dhcp, "DHCLIENT_CLIENT_ID", "")
        )
      end

      ret = {}
      Ops.set(ret, "managed", Ops.get_boolean(settings, "managed", false))
      if Builtins.haskey(settings, "ipv6")
        Ops.set(ret, "ipv6", Ops.get_boolean(settings, "ipv6", true))
      end
      Ops.set(
        ret,
        "keep_install_network",
        Ops.get_boolean(settings, "keep_install_network", false)
      )
      if Ops.greater_than(Builtins.size(modules), 0)
        Ops.set(ret, "modules", modules)
      end
      Ops.set(ret, "dns", dns) if Ops.greater_than(Builtins.size(dns), 0)
      if Ops.greater_than(Builtins.size(dhcpopts), 0)
        Ops.set(ret, "dhcp_options", dhcpopts)
      end
      if Ops.greater_than(
        Builtins.size(Ops.get_map(settings, "routing", {})),
        0
        )
        Ops.set(ret, "routing", Ops.get_map(settings, "routing", {}))
      end
      if Ops.greater_than(Builtins.size(interfaces), 0)
        Ops.set(ret, "interfaces", interfaces)
      end
      if Ops.greater_than(Builtins.size(s390_devices), 0)
        Ops.set(ret, "s390-devices", s390_devices)
      end
      if Ops.greater_than(Builtins.size(net_udev), 0)
        Ops.set(ret, "net-udev", net_udev)
      end
      deep_copy(ret)
    end
  end
end

Yast::LanAutoClient.new.main
