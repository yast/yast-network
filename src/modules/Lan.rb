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

module Yast
  class LanClass < Module
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
      Yast.import "SuSEFirewall4Network"
      Yast.import "FileUtils"
      Yast.import "PackageSystem"
      Yast.import "LanItems"
      Yast.import "ModuleLoading"
      Yast.import "Linuxrc"
      Yast.import "Report"

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

      # Lan::Read (`cache) will do nothing if initialized already.
      @initialized = false
    end

    #------------------
    # GLOBAL FUNCTIONS
    #------------------

    # Return a modification status
    # @return true if data was modified
    def Modified
      ret = LanItems.GetModified || DNS.modified || Routing.Modified ||
        NetworkConfig.Modified ||
        NetworkService.Modified
      ret
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

    def readIPv6
      @ipv6 = true

      methods =
        #         "module" : $[
        #                 "filelist" : ["ipv6", "50-ipv6.conf"],
        #                 "filepath" : "/etc/modprobe.d/",
        #                 "regexp"   : "^[[:space:]]*(install ipv6 /bin/true)"
        #         ]
        {
          "builtin" => {
            "filelist" => ["sysctl.conf"],
            "filepath" => "/etc/",
            "regexp"   => "^[[:space:]]*(net.ipv6.conf.all.disable_ipv6)[[:space:]]*=[[:space:]]*1"
          }
        }

      Builtins.foreach(methods) do |which, method|
        filelist = Ops.get_list(method, "filelist", [])
        filepath = Ops.get_string(method, "filepath", "")
        regexp = Ops.get_string(method, "regexp", "")
        Builtins.foreach(filelist) do |file|
          filename = Builtins.sformat("%1/%2", filepath, file)
          if FileUtils.Exists(filename)
            Builtins.foreach(
              Builtins.splitstring(
                Convert.to_string(SCR.Read(path(".target.string"), filename)),
                "\n"
              )
            ) do |row|
              if Ops.greater_than(
                Builtins.size(
                  Builtins.regexptokenize(String.CutBlanks(row), regexp)
                ),
                0
                )
                Builtins.y2milestone("IPv6 is disabled by '%1' method.", which)
                @ipv6 = false
              end
            end
          end
        end
      end

      nil
    end
    # Read all network settings from the SCR
    # @param [Symbol] cache:
    #  `cache=use cached data,
    #  `nocache=reread from disk (for reproposal); TODO pass to submodules
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
            # Progress stage 1/9
            _("Detect network devices"),
            # Progress stage 2/9
            _("Read driver information"),
            # Progress stage 3/9 - multiple devices may be present, really plural
            _("Read device configuration"),
            # Progress stage 4/9
            _("Read network configuration"),
            # Progress stage 5/9
            _("Read firewall settings"),
            # Progress stage 6/9
            _("Read hostname and DNS configuration"),
            # Progress stage 7/9
            _("Read installation information"),
            # Progress stage 8/9
            _("Read routing configuration"),
            # Progress stage 9/9
            _("Detect current status")
          ],
          [],
          ""
        )
      end

      return false if Abort()

      # check the environment
      #    if(!Confirm::MustBeRoot()) return false;

      return false if Abort()
      # Progress step 1/9
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

      # ReadHardware(""); /* TESTING
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 2/9
      ProgressNextStage(_("Detecting network devices...")) if @gui
      # Dont read hardware data in config mode
      NetHwDetection.Start if !Mode.config

      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 3/9 - multiple devices may be present, really plural
      ProgressNextStage(_("Reading device configuration...")) if @gui
      LanItems.Read
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 4/9
      ProgressNextStage(_("Reading network configuration...")) if @gui
      NetworkConfig.Read

      readIPv6

      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 5/9
      ProgressNextStage(_("Reading firewall settings...")) if @gui
      orig = Progress.set(false)
      SuSEFirewall4Network.Read
      Progress.set(orig) if @gui
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 6/9
      ProgressNextStage(_("Reading hostname and DNS configuration...")) if @gui
      DNS.Read
      Host.Read
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 7/9
      ProgressNextStage(_("Reading installation information...")) if @gui
      #    ReadInstallInf();
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 8/9
      ProgressNextStage(_("Reading routing configuration...")) if @gui
      Routing.Read
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 9/9
      ProgressNextStage(_("Detecting current status...")) if @gui
      NetworkService.Read
      Builtins.sleep(sl)

      return false if Abort()
      # Final progress step
      ProgressNextStage(_("Finished")) if @gui
      Builtins.sleep(sl)

      return false if Abort()
      LanItems.modified = false
      @initialized = true

      Progress.Finish if @gui

      true
    end

    # (a specialization used when a parameterless function is needed)
    # @return Read(`cache)
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
      #  SCR::Write(.target.string, "/etc/modprobe.d/ipv6", sformat("%1install ipv6 /bin/true", ipv6?"#":""));
      # uncomment to write to old place (and comment code bellow)
      #  SCR::Write(.target.string, "/etc/modprobe.d/50-ipv6.conf", sformat("%1install ipv6 /bin/true\n", ipv6?"#":""));
      filename = "/etc/sysctl.conf"
      sysctl = Convert.to_string(SCR.Read(path(".target.string"), filename))
      sysctl_row = Builtins.sformat(
        "%1net.ipv6.conf.all.disable_ipv6 = 1",
        @ipv6 ? "# " : ""
      )
      found = false # size(regexptokenize(sysctl, "(net.ipv6.conf.all.disable_ipv6)"))>0;
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
    def Write
      Builtins.y2milestone("Writing configuration")

      # Query modified flag in all components, not just LanItems - DNS,
      # Routing, NetworkConfig too in order not to discard changes made
      # outside LanItems (bnc#439235)
      if !Modified()
        Builtins.y2milestone("No changes to network setup -> nothing to write")
        return true
      end

      fw_is_installed = SuSEFirewall4Network.IsInstalled

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
      # Progress stage 8
      if fw_is_installed
        step_labels = Builtins.add(step_labels, _("Write firewall settings"))
      end
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
      Routing.Write
      Progress.set(orig)
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 6
      ProgressNextStage(_("Writing hostname and DNS configuration..."))
      # write resolv.conf after change from dhcp to static (#327074)
      # reload/restart network before this to put correct resolv.conf from dhcp-backup
      orig = Progress.set(false)
      DNS.Write
      Host.EnsureHostnameResolvable
      Host.Write
      Progress.set(orig)

      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 7
      ProgressNextStage(_("Setting up network services..."))
      writeIPv6
      Builtins.sleep(sl)

      # Show this only if SuSEfirewall is installed
      if fw_is_installed
        return false if Abort()
        # Progress step 8
        ProgressNextStage(_("Writing firewall settings..."))
        orig = Progress.set(false)
        SuSEFirewall4Network.Write
        Progress.set(orig)
        Builtins.sleep(sl)
      end

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

    # Import data.
    # It expects data described networking.rnc
    # and then passed through {LanAutoClient#FromAY}.
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
          false
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
      status_nm = nil
      status_v6 = nil
      status_virt_net = nil
      href_nm = nil
      href_v6 = nil
      href_virt_net = nil
      link_nm = nil
      link_v6 = nil
      link_virt_net = nil
      header_nm = _("Network Mode")

      if NetworkService.is_network_manager
        href_nm = "lan--nm-disable"
        # network mode: the interfaces are controlled by the user
        status_nm = _("Interfaces controlled by NetworkManager")
        # disable NetworkManager applet
        link_nm = Hyperlink(href_nm, _("Disable NetworkManager"))
      else
        href_nm = "lan--nm-enable"
        # network mode
        status_nm = _("Traditional network setup with NetControl - ifup")
        # enable NetworkManager applet
        # for virtual network proposal (bridged) don't show hyperlink to enable networkmanager
        link_nm = Hyperlink(href_nm, _("Enable NetworkManager"))
      end

      if @ipv6
        href_v6 = "ipv6-disable"
        # ipv6 support is enabled
        status_v6 = _("Support for IPv6 protocol is enabled")
        # disable ipv6 support
        link_v6 = Hyperlink(href_v6, _("Disable IPv6"))
      else
        href_v6 = "ipv6-enable"
        # ipv6 support is disabled
        status_v6 = _("Support for IPv6 protocol is disabled")
        # enable ipv6 support
        link_v6 = Hyperlink(href_v6, _("Enable IPv6"))
      end
      descr = Builtins.sformat(
        "<ul><li>%1: %2 (%3)</li></ul> \n\t\t\t     <ul><li>%4 (%5)</li></ul>",
        header_nm,
        status_nm,
        link_nm,
        status_v6,
        link_v6
      )
      if !link_virt_net.nil?
        descr = Builtins.sformat(
          "%1\n\t\t\t\t\t\t<ul><li>%2 (%3)</li></ul>",
          descr,
          status_virt_net,
          link_virt_net
        )
      end
      links = [href_nm, href_v6]
      links = Builtins.add(links, href_virt_net) if !href_virt_net.nil?
      [descr, links]
    end

    # Add a new device
    # @return true if success
    def Add
      return false if LanItems.Select("") != true
      NetworkInterfaces.Add
      true
    end

    # Delete the given device
    # @param name device to delete
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
      Builtins.foreach(LanItems.Items) do |current, _config|
        ifcfg = Ops.get_string(LanItems.Items, [current, "ifcfg"], "")
        if NetworkInterfaces.GetType(ifcfg) == "br"
          NetworkInterfaces.Edit(ifcfg)
          Builtins.y2milestone(
            "Bridge %1 with ports (%2) found",
            ifcfg,
            Ops.get_string(NetworkInterfaces.Current, "BRIDGE_PORTS", "")
          )
          skipped = Builtins.add(skipped, ifcfg)
          Builtins.foreach(
            Builtins.splitstring(
              Ops.get_string(NetworkInterfaces.Current, "BRIDGE_PORTS", ""),
              " "
            )
          ) { |port| skipped = Builtins.add(skipped, port) }
        end
        if NetworkInterfaces.GetType(ifcfg) == "bond"
          NetworkInterfaces.Edit(ifcfg)

          Builtins.foreach(LanItems.GetBondSlaves(ifcfg)) do |slave|
            Builtins.y2milestone(
              "For interface %1 found slave %2",
              ifcfg,
              slave
            )
            skipped = Builtins.add(skipped, slave)
          end
        end
        # Skip also usb device as it is not good for bridge proposal (bnc#710098)
        if NetworkInterfaces.GetType(ifcfg) == "usb"
          NetworkInterfaces.Edit(ifcfg)
          Builtins.y2milestone(
            "Usb device %1 skipped from bridge proposal",
            ifcfg
          )
          skipped = Builtins.add(skipped, ifcfg)
        end
        if NetworkInterfaces.GetValue(ifcfg, "STARTMODE") == "nfsroot"
          Builtins.y2milestone(
            "Skipped %1 interface from bridge slaves because of nfsroot.",
            ifcfg
          )
          skipped = Builtins.add(skipped, ifcfg)
        end
      end
      Builtins.y2milestone("Skipped interfaces : %1", skipped)
      deep_copy(skipped)
    end

    def ProposeVirtualized
      # in case of virtualization use special proposal
      # collect all interfaces that will be skipped from bridged proposal
      skipped = IfcfgsToSkipVirtualizedProposal()

      # first configure all connected unconfigured devices with dhcp (with default parameters)
      Builtins.foreach(LanItems.Items) do |number, lanitem|
        if IsNotEmpty(
          Ops.get_string(Convert.to_map(lanitem), ["hwinfo", "dev_name"], "")
          )
          LanItems.current = number
          valid = Ops.get_boolean(
            LanItems.getCurrentItem,
            ["hwinfo", "link"],
            false
          ) == true
          if !valid
            Builtins.y2warning("item number %1 has link:false detected", number)
          else
            if Ops.get_string(LanItems.getCurrentItem, ["hwinfo", "type"], "") == "wlan"
              Builtins.y2warning("not proposing WLAN interface")
              valid = false
            end
          end
          if !LanItems.IsCurrentConfigured && valid &&
              !Builtins.contains(
                skipped,
                Ops.get_string(
                  LanItems.getCurrentItem,
                  ["hwinfo", "dev_name"],
                  ""
                )
              )
            Builtins.y2milestone("Not configured - start proposing")
            LanItems.ProposeItem
          end
        end
      end

      # then each configuration (except bridges) move to the bridge
      # and add old device name into bridge_ports
      Builtins.foreach(LanItems.Items) do |current, _config|
        ifcfg = Ops.get_string(LanItems.Items, [current, "ifcfg"], "")
        if Builtins.contains(skipped, ifcfg)
          Builtins.y2milestone("Skipping interface %1", ifcfg)
          next
        elsif Ops.greater_than(Builtins.size(ifcfg), 0)
          NetworkInterfaces.Edit(ifcfg)
          old_config = deep_copy(NetworkInterfaces.Current)
          Builtins.y2debug("Old Config %1\n%2", ifcfg, old_config)
          new_ifcfg = Builtins.sformat(
            "br%1",
            NetworkInterfaces.GetFreeDevice("br")
          )
          Builtins.y2milestone(
            "old configuration %1, bridge %2",
            ifcfg,
            new_ifcfg
          )
          NetworkInterfaces.Name = new_ifcfg
          # from bridge interface remove all bonding-related stuff
          Builtins.foreach(NetworkInterfaces.Current) do |key, _value|
            if Builtins.issubstring(key, "BONDING")
              Ops.set(NetworkInterfaces.Current, key, nil)
            end
          end
          Ops.set(NetworkInterfaces.Current, "BRIDGE", "yes")
          Ops.set(NetworkInterfaces.Current, "BRIDGE_PORTS", ifcfg)
          Ops.set(NetworkInterfaces.Current, "BRIDGE_STP", "off")
          Ops.set(NetworkInterfaces.Current, "BRIDGE_FORWARDDELAY", "0")
          # hardcode startmode (bnc#450670), it can't be ifplugd!
          Ops.set(NetworkInterfaces.Current, "STARTMODE", "auto")
          # remove description - will be replaced by new (real) one
          NetworkInterfaces.Current = Builtins.remove(
            NetworkInterfaces.Current,
            "NAME"
          )
          # remove ETHTOOLS_OPTIONS as it is useful only for real hardware
          NetworkInterfaces.Current = Builtins.remove(
            NetworkInterfaces.Current,
            "ETHTOOLS_OPTIONS"
          )
          if NetworkInterfaces.Commit
            # reconfigure existing device as newly created bridge's port
            configure_as_bridge_port(ifcfg)

            Ops.set(LanItems.Items, [current, "ifcfg"], new_ifcfg)
            LanItems.modified = true
            LanItems.force_restart = true
            Builtins.y2internal("List %1", NetworkInterfaces.List(""))
            # re-read configuration to see new items in UI
            LanItems.Read
          end
        else
          Builtins.y2warning("empty ifcfg")
        end
      end

      nil
    end

    # Create a configuration for autoyast
    # @return true if something was proposed
    # Check if any device  is configured with DHCP.
    # @return true if any DHCP device is configured
    def AnyDHCPDevice
      # return true if there is at least one device with dhcp4, dhcp6, dhcp or dhcp+autoip
      Ops.greater_than(
        Builtins.size(
          Builtins.union(
            Builtins.union(
              NetworkInterfaces.Locate("BOOTPROTO", "dhcp4"),
              NetworkInterfaces.Locate("BOOTPROTO", "dhcp6")
            ),
            Builtins.union(
              NetworkInterfaces.Locate("BOOTPROTO", "dhcp"),
              NetworkInterfaces.Locate("BOOTPROTO", "dhcp+autoip")
            )
          )
        ),
        0
      )
    end

    # @return [Array] of packages needed when writing the config
    def Packages
      # various device types require some special packages ...
      type_requires =  {
        # for wlan require iw instead of wireless-tools (bnc#539669)
        "wlan" => "iw",
        "vlan" => "vlan",
        "br"   => "bridge-utils",
        "tun"  => "tunctl",
        "tap"  => "tunctl"
      }
      # ... and some options require special packages as well
      option_requires =  {
        "WIRELESS_AUTH_MODE" => {
          "psk" => "wpa_supplicant",
          "eap" => "wpa_supplicant"
        }
      }

      pkgs = []
      type_requires.each do |type, package|
        ifaces = NetworkInterfaces.List(type)
        next if ifaces.empty?

        Builtins.y2milestone(
          "Network interface type #{type} requires package #{package}"
        )
        pkgs << package if !PackageSystem.Installed(package)
      end

      option_requires.each do |option, option_values|
        option_values.each do |value, package|
          next if NetworkInterfaces.Locate(option, value) == []

          Builtins.y2milestone(
            "Network interface with option #{option}=#{value} requires package #{package}"
          )
          pkgs << package if !PackageSystem.Installed(package)
        end
      end

      if NetworkService.is_network_manager
        pkgs << "NetworkManager" if !PackageSystem.Installed("NetworkManager")
      end

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
      if LanItems.force_restart
        log.info("Network service activation forced")
        NetworkService.Restart
      else
        log.info "Attempting to reload network service, normal stage " \
          "#{Stage.normal}, ssh: #{Linuxrc.usessh}"

        # If the second installation stage has been called by yast.ssh via
        # ssh, we should not restart network cause systemctl
        # hangs in that case. (bnc#885640)
        NetworkService.ReloadOrRestart if Stage.normal || !Linuxrc.usessh
      end
    end
  end

  Lan = LanClass.new
  Lan.main
end
