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
# File:        modules/LanUdevAuto.ycp
# Package:     Network configuration
# Summary:     Udev rules for autoinstallation
# Authors:     Michal Zugec <mzugec@suse.cz>
#
#
# Representation of the configuration of network cards.
require "yast"
require "network/network_autoyast"
require "English"

module Yast
  class LanUdevAutoClass < Module
    include Yast::Logger

    def main
      Yast.import "LanItems"
      Yast.import "Map"
      Yast.import "Linuxrc"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/lan/udev.rb"

      @udev_rules = []
      @s390_devices = []
    end

    # @return parameter from /etc/install.inf or nil
    # @param [String] name parameter name, case sensitive
    def InstallInfParameter(name)
      p = Builtins.add(path(".etc.install_inf"), name)
      Convert.to_string(SCR.Read(p))
    end

    # @return parameter from the kernel(boot) command line or nil
    # @param [String] name parameter name, case sensitive
    def KernelCmdlineParameter(name)
      cmdline = InstallInfParameter("Cmdline")
      cmdmap = Map.FromString(cmdline) # handles nil too
      Ops.get_string(cmdmap, name)
    end

    # @return installation parameter or nil
    # @param [String] name parameter name, case sensitive
    def InstallationParameter(name)
      value = InstallInfParameter(name)
      value = KernelCmdlineParameter(name) if value.nil?
      value
    end

    # FATE#311332
    def AllowUdevModify
      InstallationParameter("biosdevname") != "1"
    end

    #  internal function:
    #  for old-slyle create udev rules and rename interface names to new-style
    def createUdevFromIfaceName(interfaces)
      udev_rules = []
      attr_map = {
        "id"  => "ATTR{address}",
        "bus" => "KERNELS"
      }

      interfaces.keep_if do |interface|
        if /.*-(?<attr>id|bus)-(?<value>.*)/ =~ interface["device"]
          udev_rules << {
            "rule"  => attr_map[attr],
            "value" => value,
            "name"  => LanItems.getDeviceName(interface["device"])
          }

          interface
        end
      end

      log.info("converted interfaces: #{interfaces}")

      udev_rules
    end

    def Import(settings)
      settings = deep_copy(settings)
      log.info("importing #{settings}")

      # So, if the profile contains old style names, then net-udev section
      # of the profile is ignored. Moreover it drops configuration for all
      # interfaces which do not use old style name
      if NetworkAutoYast.instance.oldStyle(settings)
        @udev_rules = createUdevFromIfaceName(settings["interfaces"] || [])
      else
        @udev_rules = settings["net-udev"] || []
      end

      @s390_devices = settings["s390-devices"] || []

      log.info("interfaces: #{settings["interfaces"] || []}")
      log.info("net-udev rules: #{@udev_rules}")
      log.info("s390-devices rules: #{@s390_devices}")

      true
    end

    def Write
      template = "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", %s==\"%s\", NAME=\"%s\""

      rules = @udev_rules.map do |rule|
        opt = rule["rule"] || ""
        value = rule["value"] || ""
        devname = rule["name"] || ""

        format(template, opt, value.downcase, devname)
      end

      if !rules.empty? && AllowUdevModify()
        SetAllLinksDown() if !(Linuxrc.usessh || Linuxrc.vnc)

        log.info("Writing AY udev rules for network")

        write_update_udevd(rules)

        SCR.Execute(path(".target.bash"), "udevadm settle")
      else
        log.info("No udev rules created by AY")
      end

      # FIXME: In fact, this has nothing to do with udev. At least no
      # directly. It creates linux emulation for s390 devices.
      if Arch.s390
        @s390_devices.each do |rule|
          LanItems.Select("")
          LanItems.type = Ops.get_string(rule, "type", "")
          LanItems.qeth_chanids = Ops.get_string(rule, "chanids", "")
          LanItems.qeth_layer2 = Ops.get_boolean(rule, "layer2", false)
          LanItems.qeth_portname = Ops.get_string(rule, "portname", "")
          LanItems.chan_mode = Ops.get_string(rule, "protocol", "")
          LanItems.iucv_user = Ops.get_string(rule, "router", "")
          Builtins.y2milestone("rule:%1", rule)
          Builtins.y2milestone("type:%1", LanItems.type)
          Builtins.y2milestone("chanids:%1", LanItems.qeth_chanids)
          Builtins.y2milestone("layer2:%1", LanItems.qeth_layer2)
          Builtins.y2milestone("portname:%1", LanItems.qeth_portname)
          LanItems.createS390Device
          Builtins.y2milestone("rule %1", rule)
        end
        log.info("Writing s390 rules #{@s390_devices}")
      end

      true
    end

    def Export(devices)
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
        Builtins.foreach(
          Convert.convert(
            LanItems.Items,
            from: "map <integer, any>",
            to:   "map <integer, map <string, any>>"
          )
        ) do |id, row|
          LanItems.current = id
          if Ops.greater_than(
            Builtins.size(Ops.get_string(row, "ifcfg", "")),
            0
            )
            name = LanItems.GetItemUdev("NAME")
            mac_rule = LanItems.GetItemUdev("ATTR{address}")
            bus_rule = LanItems.GetItemUdev("KERNELS")
            if Builtins.size(mac_rule) == 0 && Builtins.size(bus_rule) == 0
              Builtins.y2error("No MAC or BusID rule %1", row)
              next
            end
            Ops.set(
              ay,
              ["net-udev", name],
              "rule"  => Ops.greater_than(Builtins.size(mac_rule), 0) ? "ATTR{address}" : "KERNELS",
              "name"  => name,
              "value" => Ops.greater_than(Builtins.size(mac_rule), 0) ? mac_rule : bus_rule
            )
          end
        end
      end

      Builtins.y2milestone("AY profile %1", ay)
      deep_copy(ay)
    end

    publish function: :AllowUdevModify, type: "boolean ()"
    publish function: :getDeviceName, type: "string (string)"
    publish function: :Import, type: "boolean (map)"
    publish function: :Write, type: "boolean ()"
    publish function: :Export, type: "map (map)"
  end

  LanUdevAuto = LanUdevAutoClass.new
  LanUdevAuto.main
end
