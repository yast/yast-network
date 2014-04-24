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
      Yast.import "Hostname"
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
      Yast.import "Service"
      Yast.import "String"
      Yast.import "Summary"
      Yast.import "SuSEFirewall4Network"
      Yast.import "FileUtils"
      Yast.import "PackageSystem"
      Yast.import "LanItems"
      Yast.import "ModuleLoading"
      Yast.import "Linuxrc"
      Yast.import "Stage"
      Yast.import "LanUdevAuto"
      Yast.import "Label"

      Yast.include self, "network/complex.rb"
      Yast.include self, "network/runtime.rb"

      #-------------
      # GLOBAL DATA

      # gui or cli mode
      @gui = true

      @write_only = false

      # Current module information
      # FIXME: MOD global map Module = $[];

      # propose configuration for virtual networks (bridged) ?
      @virt_net_proposal = nil

      # autoinstallation: if true, write_only is disabled and the network settings
      # are applied at once, like during the normal installation. #128810, #168806
      # boolean start_immediately = false;

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
            :from => "any",
            :to   => "map <string, any>"
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
              :from => "any",
              :to   => "map <string, any>"
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
            :from => "list",
            :to   => "list <string>"
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
              :from => "any",
              :to   => "map <string, any>"
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
                :from => "any",
                :to   => "list <string>"
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
                  "Detected a ndiswrapper configuration,\n" +
                    "but the kernel module was not modprobed.\n" +
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
      found = false #size(regexptokenize(sysctl, "(net.ipv6.conf.all.disable_ipv6)"))>0;
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
      if !Mode.autoinst && LanUdevAuto.AllowUdevModify
        LanItems.WriteUdevRules
        # wait so that ifcfgs written in NetworkInterfaces are newer
        # (1-second-wise) than netcontrol status files,
        # and rcnetwork reload actually works (bnc#749365)
        SCR.Execute(path(".target.bash"), "udevadm settle")
        Builtins.sleep(1000)
      end
      # hack: no "netcard" filter as biosdevname names it diferently (bnc#712232)
      NetworkInterfaces.Write("")
      # WriteDevices();
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

      #Show this only if SuSEfirewall is installed
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

        Builtins.y2milestone("virt_net_proposal %1", @virt_net_proposal)
        if Stage.cont && @virt_net_proposal == true &&
            (Linuxrc.usessh || Linuxrc.vnc || Linuxrc.display_ip)

          if ConfirmVirtProposal.instance.run == :ok
            Builtins.y2milestone(
              "Restarting network because of bridged proposal"
            )
            NetworkService.Restart
          end
        # For ssh/vnc installation don't reload/restart network because possibility of IP change (bnc#347482)
        elsif Stage.cont &&
            (Linuxrc.usessh || Linuxrc.vnc || Linuxrc.display_ip)
          Builtins.y2milestone(
            "For ssh or vnc installation don't reload/restart network during installation."
          )
        elsif LanItems.force_restart
          NetworkService.Restart
        else
          NetworkService.ReloadOrRestart
        end
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

    # Import data
    # @param [Hash] settings settings to be imported
    # @return true on success
    def Import(settings)
      settings = deep_copy(settings)
      NetworkInterfaces.Import("netcard", Ops.get_map(settings, "devices", {}))
      Builtins.foreach(NetworkInterfaces.List("netcard")) do |device|
        LanItems.AddNew
        Ops.set(LanItems.Items, LanItems.current, { "ifcfg" => device })
      end

      Ops.set(
        LanItems.autoinstall_settings,
        "start_immediately",
        Ops.get_boolean(settings, "start_immediately", false)
      )
      Ops.set(
        LanItems.autoinstall_settings,
        "strict_IP_check_timeout",
        Ops.get_integer(settings, "strict_IP_check_timeout", -1)
      )
      Ops.set(
        LanItems.autoinstall_settings,
        "keep_install_network",
        Ops.get_boolean(settings, "keep_install_network", false)
      )

      NetworkConfig.Import(Ops.get_map(settings, "config", {}))
      DNS.Import(Builtins.eval(Ops.get_map(settings, "dns", {})))
      Routing.Import(Builtins.eval(Ops.get_map(settings, "routing", {})))

      if Ops.get_boolean(settings, "managed", false)
        NetworkService.use_network_manager
      else
        NetworkService.use_netconfig
      end
      if Builtins.haskey(settings, "ipv6")
        @ipv6 = Ops.get_boolean(settings, "ipv6", true)
      end

      LanItems.modified = true
      true
    end

    # Export data
    # @return dumped settings (later acceptable by Import())
    def Export
      devices = NetworkInterfaces.Export("")
      udev_rules = LanUdevAuto.Export(devices)
      ay = {
        "dns"                  => DNS.Export,
        # FIXME: MOD "modules"	: Modules,
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
        ), #start_immediately,
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
      split = mode == "split"

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
        link_nm = @virt_net_proposal ?
          "..." :
          Hyperlink(href_nm, _("Enable NetworkManager"))
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
      # no exception needed for virtualbox* (bnc#648044) http://www.virtualbox.org/manual/ch06.html
      if PackageSystem.Installed("xen") && !Arch.is_xenU ||
          PackageSystem.Installed("kvm") ||
          PackageSystem.Installed("qemu")
        if @virt_net_proposal
          href_virt_net = "virtual-revert"
          status_virt_net = _(
            "Proposed bridged configuration for virtual machine network"
          )
          link_virt_net = Hyperlink(
            href_virt_net,
            _("Use non-bridged configuration")
          )
        else
          href_virt_net = "virtual-enable"
          status_virt_net = _("Proposed non-bridged network configuration")
          link_virt_net = Hyperlink(
            href_virt_net,
            _("Use bridged configuration")
          )
        end
      end
      descr = Builtins.sformat(
        "<ul><li>%1: %2 (%3)</li></ul> \n\t\t\t     <ul><li>%4 (%5)</li></ul>",
        header_nm,
        status_nm,
        link_nm,
        status_v6,
        link_v6
      )
      if link_virt_net != nil
        descr = Builtins.sformat(
          "%1\n\t\t\t\t\t\t<ul><li>%2 (%3)</li></ul>",
          descr,
          status_virt_net,
          link_virt_net
        )
      end
      links = [href_nm, href_v6]
      links = Builtins.add(links, href_virt_net) if href_virt_net != nil
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
      if nm_feature == ""
        # compatibility: use the boolean feature
        # (defaults to false)
        nm_default = ProductFeatures.GetBooleanFeature(
          "network",
          "network_manager_is_default"
        )
      elsif nm_feature == "always"
        nm_default = true
      elsif nm_feature == "laptop"
        nm_default = Arch.is_laptop
        Builtins.y2milestone("Is a laptop: %1", nm_default) # nm_feature == "never"
      else
        nm_default = false
      end

      nm_installed = Package.Installed("NetworkManager")
      Builtins.y2milestone(
        "NetworkManager wanted: %1, installed: %2",
        nm_default,
        nm_installed
      )
      nm_default && nm_installed
    end

    # Create minimal ifcfgs for the case when NetworkManager is used:
    # NM does not need them but yast2-firewall and SuSEfirewall2 do
    # Avoid existing ifcfg from network installation
    def ProposeNMInterfaces
      Builtins.y2milestone("Minimal ifcfgs for NM")
      Builtins.foreach(LanItems.Items) do |number, lanitem|
        if IsNotEmpty(
            Ops.get_string(Convert.to_map(lanitem), ["hwinfo", "dev_name"], "")
          )
          LanItems.current = number
          if !LanItems.IsCurrentConfigured
            Builtins.y2milestone(
              "Nothing already configured start proposing %1 (NM)",
              LanItems.getCurrentItem
            )
            LanItems.ProposeItem
          end
        end
      end

      nil
    end

    def IfcfgsToSkipVirtualizedProposal
      skipped = []
      Builtins.foreach(LanItems.Items) do |current, config|
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
      Builtins.foreach(LanItems.Items) do |current, config|
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
          Builtins.foreach(NetworkInterfaces.Current) do |key, value|
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
            NetworkInterfaces.Add
            NetworkInterfaces.Edit(ifcfg)
            Ops.set(old_config, "BOOTPROTO", "static")
            Ops.set(old_config, "IPADDR", "0.0.0.0/32")
            # remove all aliases (bnc#590167)
            Builtins.foreach(
              Ops.get_map(NetworkInterfaces.Current, "_aliases", {})
            ) do |a, v|
              if v != nil
                NetworkInterfaces.DeleteAlias(NetworkInterfaces.Name, a)
              end
            end
            #take out PREFIXLEN from old configuration (BNC#735109)
            Ops.set(old_config, "PREFIXLEN", "")
            Ops.set(old_config, "_aliases", {})
            Builtins.y2milestone(
              "Old Config with apllied changes %1\n%2",
              ifcfg,
              old_config
            )
            NetworkInterfaces.Current = deep_copy(old_config)
            NetworkInterfaces.Commit

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

    # Propose interface configuration
    # @return true if something was proposed
    def ProposeInterfaces
      Builtins.y2milestone("Hardware=%1", LanItems.Hardware)

      Builtins.y2milestone("NetworkConfig::Config=%1", NetworkConfig.Config)
      Builtins.y2milestone("NetworkConfig::DHCP=%1", NetworkConfig.DHCP)

      # test if we have any virtualization installed
      if @virt_net_proposal
        Builtins.y2milestone(
          "Virtualization [xen|kvm|qemu] detected - will propose virtualization network"
        )
        ProposeVirtualized()
      else
        if !LanItems.nm_proposal_valid
          if UseNetworkManager()
            NetworkService.use_network_manager
          else
            NetworkService.use_netconfig
          end

          LanItems.nm_proposal_valid = true
        end

        if NetworkService.is_network_manager
          ProposeNMInterfaces()

          LanItems.modified = true # #144139 workaround
          Builtins.y2milestone("NM proposal")
          return true
        end
      end
      # Something is already configured -> do nothing
      configured = false
      Builtins.foreach(LanItems.Items) do |number, lanitem|
        LanItems.current = number
        if LanItems.IsCurrentConfigured
          Builtins.y2milestone("Something already configured: don't propose.")
          configured = true
          raise Break
        end
      end
      return false if configured


      Builtins.foreach(LanItems.Items) do |number, lanitem|
        if IsNotEmpty(
            Ops.get_string(Convert.to_map(lanitem), ["hwinfo", "dev_name"], "")
          )
          LanItems.current = number
          link = Ops.get_boolean(
            LanItems.getCurrentItem,
            ["hwinfo", "link"],
            false
          )
          if Ops.get_string(LanItems.getCurrentItem, ["hwinfo", "type"], "") == "wlan"
            Builtins.y2warning("Will not propose wlan interfaces")
          else
            if !link
              Builtins.y2warning(
                "item number %1 has link:false detected",
                number
              )
            elsif !LanItems.IsCurrentConfigured && link
              Builtins.y2milestone(
                "Nothing already configured - start proposing"
              )
              LanItems.ProposeItem
              raise Break
            end
          end
        end
      end

      Builtins.y2milestone("NetworkConfig::Config=%1", NetworkConfig.Config)
      Builtins.y2milestone("NetworkConfig::DHCP=%1", NetworkConfig.DHCP)

      true
    end

    # Propose the hostname
    # See also DNS::Read
    # @return true if something was proposed
    def ProposeHostname
      if DNS.proposal_valid
        # the standalone hostname dialog did the job already
        return false
      end

      true
    end

    # Propose configuration for routing and resolver
    # @return true if something was proposed
    def ProposeRoutesAndResolver
      if LanItems.bootproto == "static" && LanItems.ipaddr != "" &&
          LanItems.ipaddr != nil
        ProposeHostname()
      end
      true
    end

    # Propose a configuration
    # @return true if something was proposed
    def Propose
      NetworkInterfaces.CleanCacheRead
      LanItems.Read
      ProposeInterfaces() && ProposeRoutesAndResolver()
    end

    # Create a configuration for autoyast
    # @return true if something was proposed
    def Autoinstall
      Builtins.y2milestone("Hardware=%1", LanItems.Hardware)
      tosel = nil

      # Some HW found -> use it for proposal
      if Ops.greater_than(Builtins.size(LanItems.Hardware), 0) &&
          Ops.greater_than(
            Builtins.size(
              Ops.get_list(LanItems.autoinstall_settings, "interfaces", [])
            ),
            0
          )
        Builtins.foreach(
          Ops.get_list(LanItems.autoinstall_settings, "interfaces", [])
        ) do |interface|
          devs = NetworkInterfaces.List("")
          Builtins.y2milestone("devs: %1", devs)
          tosel = nil
          Add()
          tosel = LanItems.FindMatchingDevice(interface)
          Builtins.y2milestone("tosel=%1", tosel)
          # Read module data from autoyast
          aymodule = LanItems.GetModuleForInterface(
            Ops.get(interface, "device", ""),
            Ops.get_list(LanItems.autoinstall_settings, "modules", [])
          )
          if tosel != nil
            Ops.set(
              tosel,
              "module",
              Ops.get_string(aymodule, "module", "") != "" ?
                Ops.get_string(aymodule, "module", "") :
                Ops.get_string(tosel, "module", "")
            )
            Ops.set(
              tosel,
              "options",
              Ops.get_string(aymodule, "options", "") != "" ?
                Ops.get_string(aymodule, "options", "") :
                Ops.get_string(tosel, "options", "")
            )

            LanItems.SelectHWMap(tosel)
          else
            Builtins.y2milestone(
              "No hardware, no install.inf -> no autoinstallation possible."
            )
            next false
          end
          # The uppercasing is also done in lan_auto::FromAY
          # but the output goes to "devices" whereas here
          # we use "interfaces". FIXME.
          newk = nil
          interface = Builtins.mapmap(interface) do |k, v|
            newk = Builtins.toupper(k)
            { newk => v }
          end
          defaults = Builtins.union(
            LanItems.SysconfigDefaults,
            LanItems.GetDefaultsForHW
          )
          # Set interface variables
          LanItems.SetDeviceVars(interface, defaults)
          Builtins.y2debug(
            "ipaddr,bootproto=%1,%2",
            LanItems.ipaddr,
            LanItems.bootproto
          )
          if LanItems.bootproto == "static" && LanItems.ipaddr != "" &&
              LanItems.ipaddr != nil
            Builtins.y2milestone("static configuration")

            if LanItems.netmask == nil || LanItems.netmask == ""
              LanItems.netmask = "255.255.255.0"
            end
          end
          LanItems.Commit
        end
      else
        Builtins.y2milestone(
          "no interface configuration, taking it from install.inf"
        )
        ProposeInterfaces()
      end

      # #153426 - using ProposeInterfaces instead of Propose omitted these
      # if they are nonempty, Import has already taken care of them.
      if Ops.get_list(LanItems.autoinstall_settings, ["routing", "routes"], []) == []
        Builtins.y2milestone("gateway from install.inf") 
        #	Routing::ReadFromGateway (InstallInf["gateway"]:"");
      end
      if Ops.get_list(LanItems.autoinstall_settings, ["dns", "nameservers"], []) == []
        Builtins.y2milestone("nameserver from install.inf") 
        #	DNS::ReadNameserver (InstallInf["nameserver"]:"");
      end
      if Ops.get_string(LanItems.autoinstall_settings, ["dns", "hostname"], "") == ""
        ProposeHostname()
      end

      true
    end


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


    def PrepareForAutoinst
      #    ReadInstallInf();
      LanItems.ReadHw
      deep_copy(LanItems.Hardware)
    end

    # @return [Array] of packages needed when writing the config
    def Packages
      pkgs = []
      required = {
        "types"   => {
          #for wlan require iw instead of wireless-tools (bnc#539669)
          "wlan" => "iw",
          "vlan" => "vlan",
          "br"   => "bridge-utils",
          "tun"  => "tunctl",
          "tap"  => "tunctl"
        },
        "options" => {
          "STARTMODE"          => { "ifplugd" => "ifplugd" },
          "WIRELESS_AUTH_MODE" => {
            "psk" => "wpa_supplicant",
            "eap" => "wpa_supplicant"
          }
        }
      }

      Builtins.foreach(
        Convert.convert(
          Map.Keys(Ops.get_map(required, "types", {})),
          :from => "list",
          :to   => "list <string>"
        )
      ) do |type|
        package = Ops.get_string(required, ["types", type], "")
        if Ops.greater_than(Builtins.size(NetworkInterfaces.List(type)), 0)
          Builtins.y2milestone(
            "Network interface type %1 requires package %2",
            type,
            package
          )
          if !PackageSystem.Installed(package)
            pkgs = Builtins.add(pkgs, package)
          end
        end
      end


      Builtins.foreach(
        Convert.convert(
          Map.Keys(Ops.get_map(required, "options", {})),
          :from => "list",
          :to   => "list <string>"
        )
      ) do |type|
        Builtins.foreach(
          Convert.convert(
            Map.Keys(Ops.get_map(required, ["options", type], {})),
            :from => "list",
            :to   => "list <string>"
          )
        ) do |option|
          package = Ops.get_string(required, ["options", type, option], "")
          if NetworkInterfaces.Locate(type, option) != []
            Builtins.y2milestone(
              "Network interface with options %1, %2 requires package %3",
              type,
              option,
              package
            )
            if !PackageSystem.Installed(package)
              pkgs = Builtins.add(pkgs, package)
            end
          end
        end
      end

      if NetworkService.is_network_manager
        if !PackageSystem.Installed("NetworkManager")
          pkgs = Builtins.add(pkgs, "NetworkManager")
        end
      end
      deep_copy(pkgs)
    end

    # @return [Array] of packages needed when writing the config in autoinst
    # mode
    def AutoPackages
      { "install" => Packages(), "remove" => [] }
    end

    # Xen bridging confuses us (#178848)
    # @return whether xenbr* exists
    def HaveXenBridge
      #adapted test for xen bridged network (bnc#553794)
      have_br = FileUtils.Exists("/dev/.sysconfig/network/xenbridges")
      Builtins.y2milestone("Have Xen bridge: %1", have_br)
      have_br
    end

    publish :variable => :virt_net_proposal, :type => "boolean"
    publish :variable => :ipv6, :type => "boolean"
    publish :variable => :AbortFunction, :type => "block <boolean>"
    publish :variable => :bond_autoconf_slaves, :type => "list <string>"
    publish :function => :Modified, :type => "boolean ()"
    publish :function => :isAnyInterfaceDown, :type => "boolean ()"
    publish :function => :Read, :type => "boolean (symbol)"
    publish :function => :ReadWithCache, :type => "boolean ()"
    publish :function => :ReadWithCacheNoGUI, :type => "boolean ()"
    publish :function => :SetIPv6, :type => "void (boolean)"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :WriteOnly, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Summary, :type => "list (string)"
    publish :function => :SummaryGeneral, :type => "list ()"
    publish :function => :Add, :type => "boolean ()"
    publish :function => :Delete, :type => "boolean ()"
    publish :function => :ProposeInterfaces, :type => "boolean ()"
    publish :function => :ProposeRoutesAndResolver, :type => "boolean ()"
    publish :function => :Propose, :type => "boolean ()"
    publish :function => :Autoinstall, :type => "boolean ()"
    publish :function => :AnyDHCPDevice, :type => "boolean ()"
    publish :function => :PrepareForAutoinst, :type => "list <map> ()"
    publish :function => :Packages, :type => "list <string> ()"
    publish :function => :AutoPackages, :type => "map ()"
    publish :function => :HaveXenBridge, :type => "boolean ()"
  end

  Lan = LanClass.new
  Lan.main
end
