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
require "network/install_inf_convertor"

module Yast
  class LanUdevAutoClass < Module
    include Yast::Logger

    def main
      Yast.import "LanItems"
      Yast.import "Linuxrc"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/lan/udev.rb"

      @udev_rules = []
      @s390_devices = []
    end

    def Import(settings)
      settings = deep_copy(settings)
      log.info("importing #{settings}")

      # So, if the profile contains old style names, then net-udev section
      # of the profile is ignored. Moreover it drops configuration for all
      # interfaces which do not use old style name
      if NetworkAutoYast.instance.oldStyle(settings)
        @udev_rules = LanItems.createUdevFromIfaceName(settings["interfaces"] || [])
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

      if !rules.empty? && InstallInfConvertor.instance.AllowUdevModify
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
          LanItems.createS390Device(rule)
        end
        log.info("Writing s390 rules #{@s390_devices}")
      end

      true
    end

    publish function: :Import, type: "boolean (map)"
    publish function: :Write, type: "boolean ()"
    publish function: :Export, type: "map (map)"
  end

  LanUdevAuto = LanUdevAutoClass.new
  LanUdevAuto.main
end
