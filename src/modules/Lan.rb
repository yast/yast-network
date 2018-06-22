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
# File:	modules/Lan.ycp
# Package:	Network configuration
# Summary:	Network card data
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Representation of the configuration of network cards.
# Input and output routines.
require "yast"
require "network/confirm_virt_proposal"
require "ui/text_helpers"

module Yast
  class LanClass < Module
    include ::UI::TextHelpers

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Arch"
      Yast.import "DNS"
      Yast.import "NetHwDetection"
      Yast.import "Host"
      Yast.import "IP"
      Yast.import "Map"
      Yast.import "Mode"
      Yast.import "NetworkConfig"
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Package"
      Yast.import "ProductFeatures"
      Yast.import "Routing"
      Yast.import "Progress"
      Yast.import "String"
      Yast.import "FileUtils"
      Yast.import "PackageSystem"
      Yast.import "LanItems"
      Yast.import "ModuleLoading"
      Yast.import "Linuxrc"

      Yast.include self, "network/complex.rb"
      Yast.include self, "network/runtime.rb"
      Yast.include self, "network/lan/bridge.rb"

      #-------------
      # GLOBAL DATA

      # gui or cli mode
      @gui = true

      @write_only = false

      # ipv6 module
      @ipv6 = true

      # Hotplug type ("" if not hot pluggable)

      # Abort function
      # return boolean return true if abort
      @AbortFunction = nil

      # list of interface names which were recently assigned as a slave to a bond device
      @bond_autoconf_slaves = []

      # list of interface names which were recently enslaved in a bridge or bond device
      @autoconf_slaves = []

      # Lan::Read (`cache) will do nothing if initialized already.
      @initialized = false
    end

    #------------------
    # GLOBAL FUNCTIONS
    #------------------

    # Return a modification status
    # @return true if data was modified
    def Modified
      return true if LanItems.GetModified
      return true if DNS.modified
      return true if Routing.Modified
      return true if NetworkConfig.Modified
      return true if NetworkService.Modified
      return true if Host.GetModified

      false
    end

    # function for use from autoinstallation (Fate #301032)
    def isAnyInterfaceDown
      down = false
      link_status = {}
      net_devices = Builtins.splitstring(
        Ops.get_string(
          Convert.convert(
            SCR.Execute(
              path(".target.bash_output"),
              "ls /sys/class/net/ | grep -v lo | tr '\n' ','"
            ),
            from: "any",
            to:   "map <string, any>"
          ),
          "stdout",
          ""
        ),
        ","
      )
      net_devices = Builtins.filter(net_devices) do |item|
        Ops.greater_than(Builtins.size(item), 0)
      end
      Builtins.foreach(net_devices) do |net_dev|
        row = Builtins.splitstring(
          Ops.get_string(
            Convert.convert(
              SCR.Execute(
                path(".target.bash_output"),
                Builtins.sformat(
                  "ip address show dev %1 | grep 'inet\\|link' | sed 's/^ \\+//g'|cut -d' ' -f-2",
                  net_dev
                )
              ),
              from: "any",
              to:   "map <string, any>"
            ),
            "stdout",
            ""
          ),
          "\n"
        )
        tmp_mac = ""
        addr = false
        Builtins.foreach(row) do |column|
          tmp_col = Builtins.splitstring(column, " ")
          next if Ops.less_than(Builtins.size(tmp_col), 2)
          if Builtins.issubstring(Ops.get(tmp_col, 0, ""), "link/ether")
            tmp_mac = Ops.get(tmp_col, 1, "")
          end
          if Builtins.issubstring(Ops.get(tmp_col, 0, ""), "inet") &&
              !Builtins.issubstring(Ops.get(tmp_col, 0, ""), "inet6")
            addr = true
          end
        end
        if Ops.greater_than(Builtins.size(tmp_mac), 0)
          Ops.set(link_status, tmp_mac, addr)
        end
        Builtins.y2debug("link_status %1", link_status)
      end

      Builtins.y2milestone("link_status %1", link_status)
      configurations = NetworkInterfaces.FilterDevices("")
      Builtins.foreach(
        Builtins.splitstring(
          Ops.get(NetworkInterfaces.CardRegex, "netcard", ""),
          "|"
        )
      ) do |devtype|
        Builtins.foreach(
          Convert.convert(
            Map.Keys(Ops.get_map(configurations, devtype, {})),
            from: "list",
            to:   "list <string>"
          )
        ) do |devname|
          mac = Ops.get_string(
            Convert.convert(
              SCR.Execute(
                path(".target.bash_output"),
                Builtins.sformat(
                  "cat /sys/class/net/%1/address|tr -d '\n'",
                  devname
                )
              ),
              from: "any",
              to:   "map <string, any>"
            ),
            "stdout",
            ""
          )
          Builtins.y2milestone("confname %1", mac)
          if !Builtins.haskey(link_status, mac)
            Builtins.y2error(
              "Mac address %1 not found in map %2!",
              mac,
              link_status
            )
          elsif Ops.get_boolean(link_status, mac, false) == false
            Builtins.y2warning("Interface with mac %1 is down!", mac)
            down = true
          else
            Builtins.y2debug("Interface with mac %1 is up", mac)
          end
        end
      end
      down
    end

    # Checks local configuration if IPv6 is allowed
    #
    # return [Boolean] true when IPv6 is enabled in the system
    def readIPv6
      ipv6 = true

      sysctl_path = "/etc/sysctl.conf"
      ipv6_regexp = /^[[:space:]]*(net.ipv6.conf.all.disable_ipv6)[[:space:]]*=[[:space:]]*1/

      # sysctl.conf is kind of "mandatory" config file, use default
      if !FileUtils.Exists(sysctl_path)
        log.error("readIPv6: #{sysctl_path} is missing")
        return true
      end

      lines = (SCR.Read(path(".target.string"), sysctl_path) || []).split("\n")
      ipv6 = false if lines.any? { |row| row =~ ipv6_regexp }

      log.info("readIPv6: IPv6 is #{ipv6 ? "enabled" : "disabled"}")

      ipv6
    end

    # Read all network settings from the SCR
    # @param cache [Symbol] :cache=use cached data, :nocache=reread from disk TODO pass to submodules
    # @return true on success
    def Read(cache)
      if cache == :cache && @initialized
        Builtins.y2milestone("Using cached data")
        return true
      end

      # Read dialog caption
      caption = _("Initializing Network Configuration")
      steps = 9

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      if @gui
        Progress.New(
          caption,
          " ",
          steps,
          [
            # Progress stage 1/8
            _("Detect network devices"),
            # Progress stage 2/8
            _("Read driver information"),
            # Progress stage 3/8 - multiple devices may be present, really plural
            _("Read device configuration"),
            # Progress stage 4/8
            _("Read network configuration"),
            # Progress stage 5/8
            _("Read hostname and DNS configuration"),
            # Progress stage 6/8
            _("Read installation information"),
            # Progress stage 8/8
            _("Read routing configuration"),
            # Progress stage 9/8
            _("Detect current status")
          ],
          [],
          ""
        )
      end

      return false if Abort()
      ProgressNextStage(_("Detecting ndiswrapper...")) if @gui
      # modprobe ndiswrapper before hwinfo when needed (#343893)
      if !Mode.autoinst && PackageSystem.Installed("ndiswrapper")
        Builtins.y2milestone("ndiswrapper: installed")
        if Ops.greater_than(
          Builtins.size(
            Convert.convert(
              SCR.Read(path(".target.dir"), "/etc/ndiswrapper"),
              from: "any",
              to:   "list <string>"
            )
          ),
          0
        )
          Builtins.y2milestone("ndiswrapper: configuration found")
          if Convert.to_integer(
            SCR.Execute(path(".target.bash"), "lsmod |grep -q ndiswrapper")
          ) != 0 &&
              Popup.YesNo(
                _(
                  "Detected a ndiswrapper configuration,\n" \
                    "but the kernel module was not modprobed.\n" \
                    "Do you want to modprobe ndiswrapper?\n"
                )
              )
            if ModuleLoading.Load("ndiswrapper", "", "", "", false, true) == :fail
              Popup.Error(
                _(
                  "ndiswrapper kernel module has not been loaded.\nCheck configuration manually.\n"
                )
              )
            end
          end
        end
      end

      Builtins.sleep(sl)

      return false if Abort()
      ProgressNextStage(_("Detecting network devices...")) if @gui
      # Dont read hardware data in config mode
      NetHwDetection.Start if !Mode.config

      Builtins.sleep(sl)

      return false if Abort()
      ProgressNextStage(_("Reading device configuration...")) if @gui
      LanItems.Read

      Builtins.sleep(sl)

      return false if Abort()
      ProgressNextStage(_("Reading network configuration...")) if @gui
      begin
        NetworkConfig.Read

        @ipv6 = readIPv6

        Builtins.sleep(sl)

        return false if Abort()
        ProgressNextStage(_("Reading hostname and DNS configuration...")) if @gui
        DNS.Read

        Host.Read
        Builtins.sleep(sl)

        return false if Abort()
        ProgressNextStage(_("Reading routing configuration...")) if @gui
        Routing.Read
        Builtins.sleep(sl)

        return false if Abort()
        ProgressNextStage(_("Detecting current status...")) if @gui
        NetworkService.Read
        Builtins.sleep(sl)

        return false if Abort()
      rescue IOError, SystemCallError, RuntimeError => error
        msg = format(_("Network configuration is corrupted.\n"\
                "If you continue resulting configuration can be malformed."\
                "\n\n%s"), wrap_text(error.message))
        return false if !@gui
        return false if !Popup.ContinueCancel(msg)
      end

      # Final progress step
      ProgressNextStage(_("Finished")) if @gui
      Builtins.sleep(sl)

      return false if Abort()
      @initialized = true

      fix_dhclient_warning(LanItems.invalid_dhcp_cfgs) if @gui && !LanItems.valid_dhcp_cfg?

      Progress.Finish if @gui

      true
    end

    # (a specialization used when a parameterless function is needed)
    # @return [Boolean] true on success
    def ReadWithCache
      Read(:cache)
    end

    def ReadWithCacheNoGUI
      @gui = false
      ReadWithCache()
    end

    def SetIPv6(status)
      if @ipv6 != status
        @ipv6 = status
        Popup.Warning(_("To apply this change, a reboot is needed."))
        LanItems.SetModified
      end

      nil
    end

    def writeIPv6
      filename = "/etc/sysctl.conf"
      sysctl = Convert.to_string(SCR.Read(path(".target.string"), filename))
      sysctl_row = Builtins.sformat(
        "%1net.ipv6.conf.all.disable_ipv6 = 1",
        @ipv6 ? "# " : ""
      )
      found = false
      file = []
      Builtins.foreach(Builtins.splitstring(sysctl, "\n")) do |row|
        if Ops.greater_than(
          Builtins.size(
            Builtins.regexptokenize(row, "(net.ipv6.conf.all.disable_ipv6)")
          ),
          0
        )
          row = sysctl_row
          found = true
        end
        file = Builtins.add(file, row)
      end
      file = Builtins.add(file, sysctl_row) if !found
      SCR.Write(
        path(".target.string"),
        filename,
        Builtins.mergestring(file, "\n")
      )
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "sysctl -w net.ipv6.conf.all.disable_ipv6=%1",
          !@ipv6 ? "1" : "0"
        )
      )
      SCR.Write(
        path(".sysconfig.windowmanager.KDE_USE_IPV6"),
        @ipv6 ? "yes" : "no"
      )

      nil
    end

    # Update the SCR according to network settings
    # @return true on success
    def Write(gui: true)
      Builtins.y2milestone("Writing configuration")

      # Query modified flag in all components, not just LanItems - DNS,
      # Routing, NetworkConfig too in order not to discard changes made
      # outside LanItems (bnc#439235)
      if !Modified()
        Builtins.y2milestone("No changes to network setup -> nothing to write")
        return true
      end

      # Write dialog caption
      caption = _("Saving Network Configuration")

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      step_labels = [
        # Progress stage 2
        _("Write drivers information"),
        # Progress stage 3 - multiple devices may be present,really plural
        _("Write device configuration"),
        # Progress stage 4
        _("Write network configuration"),
        # Progress stage 5
        _("Write routing configuration"),
        # Progress stage 6
        _("Write hostname and DNS configuration"),
        # Progress stage 7
        _("Set up network services")
      ]

      # Progress stage 9
      if !@write_only
        step_labels = Builtins.add(step_labels, _("Activate network services"))
      end
      # Progress stage 10
      step_labels = Builtins.add(step_labels, _("Update configuration"))

      Progress.New(
        caption,
        " ",
        Builtins.size(step_labels),
        step_labels,
        [],
        ""
      )

      return false if Abort()
      # Progress step 2
      ProgressNextStage(_("Writing /etc/modprobe.conf..."))
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 3 - multiple devices may be present, really plural
      ProgressNextStage(_("Writing device configuration..."))
      LanItems.write
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 4
      ProgressNextStage(_("Writing network configuration..."))
      NetworkConfig.Write
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 5
      ProgressNextStage(_("Writing routing configuration..."))
      orig = Progress.set(false)
      Routing.Write(gui: gui)
      Progress.set(orig)
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 6
      ProgressNextStage(_("Writing hostname and DNS configuration..."))
      # write resolv.conf after change from dhcp to static (#327074)
      # reload/restart network before this to put correct resolv.conf from dhcp-backup
      orig = Progress.set(false)
      DNS.Write(gui: gui)
      Host.EnsureHostnameResolvable
      Host.Write(gui: gui)
      Progress.set(orig)

      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 7
      ProgressNextStage(_("Setting up network services..."))
      writeIPv6
      Builtins.sleep(sl)

      if !@write_only
        return false if Abort()
        # Progress step 9
        ProgressNextStage(_("Activating network services..."))
        # during installation export sysconfig settings into NetworkManager (bnc#433084)
        if Mode.installation && NetworkService.is_network_manager
          Builtins.y2internal(
            "Export sysconfig settings into NetworkManager %1",
            SCR.Execute(
              path(".target.bash_output"),
              "/usr/lib/NetworkManager/nm-opensuse-sysconfig-merge --connections"
            )
          )
        end

        activate_network_service

        Builtins.sleep(sl)
      end

      return false if Abort()
      # Progress step 10
      ProgressNextStage(_("Updating configuration..."))
      update_mta_config if !@write_only
      Builtins.sleep(sl)

      if NetworkService.is_network_manager
        network = false
        timeout = 15
        while Ops.greater_than(timeout, 0)
          if NetworkService.isNetworkRunning
            network = true
            break
          end
          Builtins.y2milestone("waiting for network ... %1", timeout)
          Builtins.sleep(1000)
          timeout = Ops.subtract(timeout, 1)
        end

        Popup.Error(_("No network running")) unless network
      end

      # Final progress step
      ProgressNextStage(_("Finished"))
      Builtins.sleep(sl)

      Progress.Finish

      return false if Abort()
      true
    end

    # Only write configuration without starting any init scripts and SuSEconfig
    # @return true on success
    def WriteOnly
      @write_only = !Ops.get_boolean(
        LanItems.autoinstall_settings,
        "start_immediately",
        false
      )
      Write()
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
    # FIXME: massive refactoring required
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
          newk = if k == "aliases"
            "_aliases"
          else
            Builtins.toupper(k)
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

    # Import data.
    # It expects data described networking.rnc
    # and then passed through {Lan#FromAY}.
    # Most prominently, instead of a flat list called "interfaces"
    # we import a 2-level map of typed "devices"
    # @param [Hash] settings settings to be imported
    # @return true on success
    def Import(settings)
      settings = {} if settings.nil?

      LanItems.Import(settings)
      NetworkConfig.Import(settings["config"] || {})
      DNS.Import(settings["dns"] || {})
      Routing.Import(settings["routing"] || {})

      # Ensure that the /etc/hosts has been read to no blank out it in case of
      # not defined <host> section (bsc#1058396)
      Host.Read

      @ipv6 = settings.fetch("ipv6", true)

      true
    end

    # Export data.
    # They need to be passed through {LanAutoClient#ToAY} to become
    # what networking.rnc describes.
    # Most prominently, instead of a flat list called "interfaces"
    # we export a 2-level map of typed "devices"
    # @return dumped settings
    def Export
      devices = NetworkInterfaces.Export("")
      udev_rules = LanItems.export(devices)
      ay = {
        "dns"                  => DNS.Export,
        "s390-devices"         => Ops.get_map(
          udev_rules,
          "s390-devices",
          {}
        ),
        "net-udev"             => Ops.get_map(udev_rules, "net-udev", {}),
        "config"               => NetworkConfig.Export,
        "devices"              => devices,
        "ipv6"                 => @ipv6,
        "routing"              => Routing.Export,
        "managed"              => NetworkService.is_network_manager,
        "start_immediately"    => Ops.get_boolean(
          LanItems.autoinstall_settings,
          "start_immediately",
          false
        ), # start_immediately,
        "keep_install_network" => Ops.get_boolean(
          LanItems.autoinstall_settings,
          "keep_install_network",
          true
        )
      }
      Builtins.y2milestone("Exported map: %1", ay)
      deep_copy(ay)
    end

    # Create a textual summary and a list of unconfigured devices
    # @param [String] mode "split": split configured and unconfigured?<br />
    #             "summary": add resolver and routing symmary,
    #		"proposal": for proposal, add links for direct config
    # @return summary of the current configuration
    def Summary(mode)
      sum = LanItems.BuildLanOverview

      # Testing improved summary
      if mode == "summary"
        Ops.set(
          sum,
          0,
          Ops.add(
            Ops.add(Ops.get_string(sum, 0, ""), DNS.Summary),
            Routing.Summary
          )
        )
      end

      deep_copy(sum)
    end

    # Create a textual summary for the general network settings
    # proposal (NetworkManager + ipv6)
    # @return [rich text, links]
    def SummaryGeneral
      # header for network summary list
      header_nm = _("Network Mode")

      if NetworkService.is_network_manager
        href_nm = "lan--nm-disable"
        # network mode: the interfaces are controlled by the user
        status_nm = _("Interfaces controlled by NetworkManager")
        # switch from network manager to wicked
        link_nm = Hyperlink(href_nm, _("switch to Wicked"))
      else
        href_nm = "lan--nm-enable"
        # network mode
        status_nm = _("Traditional network setup with Wicked")
        # switch from wicked to network manager
        link_nm = Hyperlink(href_nm, _("switch to NetworkManager"))
      end

      if @ipv6
        href_v6 = "ipv6-disable"
        # ipv6 support is enabled
        status_v6 = _("Support for IPv6 protocol is enabled")
        # disable ipv6 support
        link_v6 = Hyperlink(href_v6, _("disable"))
      else
        href_v6 = "ipv6-enable"
        # ipv6 support is disabled
        status_v6 = _("Support for IPv6 protocol is disabled")
        # enable ipv6 support
        link_v6 = Hyperlink(href_v6, _("enable"))
      end
      descr = Builtins.sformat(
        "<ul><li>%1: %2 (%3)</li></ul> \n\t\t\t     <ul><li>%4 (%5)</li></ul>",
        header_nm,
        status_nm,
        link_nm,
        status_v6,
        link_v6
      )
      links = [href_nm, href_v6]
      [descr, links]
    end

    # Add a new device
    # @return true if success
    def Add
      return false if LanItems.Select("") != true
      NetworkInterfaces.Add
      true
    end

    # Delete current device (see LanItems::current)
    # @return true if success
    def Delete
      LanItems.DeleteItem
      true
    end

    # Uses product info and is subject to installed packages.
    # @return Should NM be enabled?
    def UseNetworkManager
      nm_default = false
      nm_feature = ProductFeatures.GetStringFeature(
        "network",
        "network_manager"
      )

      case nm_feature
      when ""
        # compatibility: use the boolean feature
        # (defaults to false)
        nm_default = ProductFeatures.GetBooleanFeature(
          "network",
          "network_manager_is_default"
        )
      when "always"
        nm_default = true
      when "laptop"
        nm_default = Arch.is_laptop
        log.info("Is a laptop: #{nm_default}")
      end

      nm_installed = Package.Installed("NetworkManager")
      log.info("NetworkManager wanted: #{nm_default}, installed: #{nm_installed}")

      nm_default && nm_installed
    end

    def IfcfgsToSkipVirtualizedProposal
      skipped = []

      LanItems.Items.each do |_current, config|
        ifcfg = config["ifcfg"]
        ifcfg_type = NetworkInterfaces.GetType(ifcfg)

        case ifcfg_type
        when "br"
          skipped << ifcfg

          bridge_ports = NetworkInterfaces.GetValue(ifcfg, "BRIDGE_PORTS").to_s

          bridge_ports.split.each { |port| skipped << port }
        when "bond"
          LanItems.GetBondSlaves(ifcfg).each do |slave|
            log.info("For interface #{ifcfg} found slave #{slave}")
            skipped << slave
          end

        # Skip also usb and wlan devices as they are not good for bridge proposal (bnc#710098)
        when "usb", "wlan"
          log.info("#{ifcfg_type} device #{ifcfg} skipped from bridge proposal")
          skipped << ifcfg
        end

        next unless NetworkInterfaces.GetValue(ifcfg, "STARTMODE") == "nfsroot"

        log.info("Skipped #{ifcfg} interface from bridge slaves because of nfsroot.")

        skipped << ifcfg
      end
      log.info("Skipped interfaces : #{skipped}")

      skipped
    end

    def ProposeVirtualized
      # then each configuration (except bridges) move to the bridge
      # and add old device name into bridge_ports
      LanItems.Items.each do |current, config|
        bridge_name = format("br%s", NetworkInterfaces.GetFreeDevice("br"))
        next unless connected_and_bridgeable?(bridge_name, current, config)
        LanItems.current = current
        # first configure all connected unconfigured devices with dhcp (with default parameters)
        next if !LanItems.IsCurrentConfigured && !LanItems.ProposeItem
        ifcfg = LanItems.GetCurrentName
        next unless configure_as_bridge!(ifcfg, bridge_name)
        # reconfigure existing device as newly created bridge's port
        configure_as_bridge_port(ifcfg)
        refresh_lan_items
      end

      nil
    end

    # Proposes additional packages when needed by current networking setup
    #
    # @return [Array] of packages needed when writing the config
    def Packages
      pkgs = []

      if NetworkService.is_network_manager
        pkgs << "NetworkManager" if !PackageSystem.Installed("NetworkManager")
      elsif !PackageSystem.Installed("wpa_supplicant")
        # we have to add wpa_supplicant when wpa is in game, wicked relies on it
        pkgs << "wpa_supplicant" if !NetworkInterfaces.Locate("WIRELESS_AUTH_MODE", "psk").empty?
        pkgs << "wpa_supplicant" if !NetworkInterfaces.Locate("WIRELESS_AUTH_MODE", "eap").empty?
      end

      pkgs.uniq!

      log.info("Additional packages requested by yast2-network: #{pkgs.inspect}") if !pkgs.empty?

      pkgs
    end

    # @return [Array] of packages needed when writing the config in autoinst
    # mode
    def AutoPackages
      { "install" => Packages(), "remove" => [] }
    end

    # Xen bridging confuses us (#178848)
    # @return whether xenbr* exists
    def HaveXenBridge
      # adapted test for xen bridged network (bnc#553794)
      have_br = FileUtils.Exists("/dev/.sysconfig/network/xenbridges")
      Builtins.y2milestone("Have Xen bridge: %1", have_br)
      have_br
    end

    publish variable: :ipv6, type: "boolean"
    publish variable: :AbortFunction, type: "block <boolean>"
    publish variable: :bond_autoconf_slaves, type: "list <string>"
    publish variable: :autoconf_slaves, type: "list <string>"
    publish function: :Modified, type: "boolean ()"
    publish function: :isAnyInterfaceDown, type: "boolean ()"
    publish function: :Read, type: "boolean (symbol)"
    publish function: :ReadWithCache, type: "boolean ()"
    publish function: :ReadWithCacheNoGUI, type: "boolean ()"
    publish function: :SetIPv6, type: "void (boolean)"
    publish function: :Write, type: "boolean ()"
    publish function: :WriteOnly, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :Summary, type: "list (string)"
    publish function: :SummaryGeneral, type: "list ()"
    publish function: :Add, type: "boolean ()"
    publish function: :Delete, type: "boolean ()"
    publish function: :AnyDHCPDevice, type: "boolean ()"
    publish function: :Packages, type: "list <string> ()"
    publish function: :AutoPackages, type: "map ()"
    publish function: :HaveXenBridge, type: "boolean ()"

  private

    def activate_network_service
      # If the second installation stage has been called by yast.ssh via
      # ssh, we should not restart network because systemctl
      # hangs in that case. (bnc#885640)
      action = :reload_restart   if Stage.normal || !Linuxrc.usessh
      action = :force_restart    if LanItems.force_restart
      action = :remote_installer if Stage.initial && (Linuxrc.usessh || Linuxrc.vnc)

      case action
      when :force_restart
        log.info("Network service activation forced")
        NetworkService.Restart

      when :reload_restart
        log.info("Attempting to reload network service, normal stage #{Stage.normal}, ssh: #{Linuxrc.usessh}")

        NetworkService.ReloadOrRestart if Stage.normal || !Linuxrc.usessh

      when :remote_installer
        ifaces = LanItems.getNetworkInterfaces

        # last instance handling "special" cases like ssh installation
        # FIXME: most probably not everything will be set properly
        log.info("Running in ssh/vnc installer -> just setting links up")
        log.info("Available interfaces: #{ifaces}")

        LanItems.reload_config(ifaces)
      end
    end

    def configure_as_bridge!(ifcfg, bridge_name)
      return false if !NetworkInterfaces.Edit(ifcfg)

      old_config = deep_copy(NetworkInterfaces.Current)
      log.debug("Old Config #{ifcfg}\n#{old_config}")

      log.info("old configuration #{ifcfg}, bridge #{bridge_name}")

      NetworkInterfaces.Name = bridge_name

      # from bridge interface remove all bonding-related stuff
      NetworkInterfaces.Current.each do |key, _value|
        NetworkInterfaces.Current[key] = nil if key.include? "BONDING"
      end

      NetworkInterfaces.Current["BRIDGE"] = "yes"
      NetworkInterfaces.Current["BRIDGE_PORTS"] = ifcfg
      NetworkInterfaces.Current["BRIDGE_STP"] = "off"
      NetworkInterfaces.Current["BRIDGE_FORWARDDELAY"] = "0"

      # hardcode startmode (bnc#450670), it can't be ifplugd!
      NetworkInterfaces.Current["STARTMODE"] = "auto"
      # remove description - will be replaced by new (real) one
      NetworkInterfaces.Current.delete("NAME")
      # remove ETHTOOLS_OPTIONS as it is useful only for real hardware
      NetworkInterfaces.Current.delete("ETHTOOLS_OPTIONS")

      NetworkInterfaces.Commit
    end

    # Convenience method that returns true if the current item has link and can
    # be enslabed in a bridge.
    #
    # @return [Boolean] true if it is bridgeable
    def connected_and_bridgeable?(bridge_name, item, config)
      if !LanItems.IsBridgeable(bridge_name, item)
        log.info "The interface #{config["ifcfg"]} cannot be proposed as bridge."
        return false
      end

      hwinfo = config.fetch("hwinfo", {})
      unless hwinfo.fetch("link", false)
        log.warn("Lan item #{item} has link:false detected")
        return false
      end
      if hwinfo.fetch("type", "") == "wlan"
        log.warn("Not proposing WLAN interface for lan item: #{item}")
        return false
      end
      true
    end

    def refresh_lan_items
      LanItems.force_restart = true
      log.info("List #{NetworkInterfaces.List("")}")
      # re-read configuration to see new items in UI
      LanItems.Read

      # note: LanItems.Read resets modification flag
      # the Read is used as a trick how to update LanItems' internal
      # cache according NetworkInterfaces' one. As NetworkInterfaces'
      # cache was edited directly, LanItems is not aware of changes.
      LanItems.SetModified
    end
  end

  Lan = LanClass.new
  Lan.main
end
