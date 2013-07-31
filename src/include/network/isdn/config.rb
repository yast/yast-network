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
# File:	modules/ISDN.ycp
# Package:	Network configuration
# Summary:	ISDN data
# Authors:	Michal Svec  <msvec@suse.cz>
#		Karsten Keil <kkeil@suse.de>
#
#
# Representation of the configuration of ISDN.
# Input and output routines.
module Yast
  module NetworkIsdnConfigInclude
    def initialize_network_isdn_config(include_target)
      textdomain "network"

      Yast.import "Map"
      Yast.include include_target, "network/routines.rb"
    end

    # Read Devices from files
    # @param [String] devregex regular expression for the device type
    # @return true if sucess
    # @example ReadISDNConfig("eth|tr");
    def ReadISDNConfig(devregex)
      sysconfig = "/etc/sysconfig/isdn"

      devices = SCR.Dir(path(".isdn.section"))
      devices = Builtins.filter(devices) do |file|
        !Builtins.regexpmatch(file, "[.~]")
      end
      devices = Builtins.filter(devices) do |file|
        Builtins.regexpmatch(file, "^.*/isdn/cfg-.*")
      end

      devices = Builtins.filter(devices) do |file|
        Builtins.regexpmatch(file, devregex)
      end if devregex != nil &&
        devregex != ""
      Builtins.maplist(devices) do |d|
        devtype = Builtins.regexpsub(d, "^.*/cfg-([a-z]+)[^a-z]*$", "\\1")
        next if devtype == nil
        devnum = Builtins.regexpsub(d, "^.*/cfg-[a-z]+([0-9]+)", "\\1")
        devname = Builtins.sformat("%1%2", devtype, devnum)
        next if devnum == nil
        Builtins.y2debug("devtype=%1 devnum=%2", devtype, devnum)
        dev = Ops.get(@Devices, devtype, {})
        if Builtins.haskey(dev, devname)
          Builtins.y2error("device already present: %1", devname)
          next
        end
        pth = Ops.add(
          Ops.add(
            Ops.add(Ops.add(".isdn.value.\"", sysconfig), "/cfg-"),
            devname
          ),
          "\""
        )
        values = SCR.Dir(Builtins.topath(pth))
        config = Builtins.listmap(values) do |val|
          item = Convert.to_string(
            SCR.Read(Builtins.topath(Ops.add(Ops.add(pth, "."), val)))
          )
          next { val => item } if item != nil
        end
        Ops.set(dev, devname, config)
        Ops.set(@Devices, devtype, dev)
      end

      Builtins.y2debug("Devices=%1", @Devices)
      true
    end

    # Write Devices to files
    # @return true if success
    def WriteISDNConfig(isdntyp)
      Builtins.y2debug("Devices=%1", @Devices)
      sysconfig = "/etc/sysconfig/isdn"

      # remove deleted devices
      devs = Builtins.filter(@DeletedDevices) do |x|
        Builtins.regexpmatch(x, isdntyp)
      end
      Builtins.maplist(devs) do |d|
        p = Builtins.topath(
          Ops.add(
            Ops.add(Ops.add(Ops.add(".isdn.section.\"", sysconfig), "/cfg-"), d),
            "\""
          )
        )
        Builtins.y2debug("deleting: %1", p)
        SCR.Write(p, nil)
      end

      # write all devices
      Builtins.maplist(@Devices) do |typ, devsmap|
        Builtins.maplist(
          Convert.convert(devsmap, :from => "map", :to => "map <string, map>")
        ) do |dev, devmap|
          # write sysconfig
          next if typ != isdntyp
          p = Ops.add(
            Ops.add(Ops.add(Ops.add(".isdn.value.\"", sysconfig), "/cfg-"), dev),
            "\"."
          )
          # write all keys to config
          Builtins.maplist(
            Convert.convert(
              Map.Keys(devmap),
              :from => "list",
              :to   => "list <string>"
            )
          ) do |k|
            next if k == "module" || k == "options"
            SCR.Write(
              Builtins.topath(Ops.add(p, k)),
              Ops.get_string(devmap, k, "")
            )
          end #	    string unq = devmap["UDI"]:"";
          #	    if(unq != "") SCR::Write(.probe.status.configured, unq, `yes);
        end
      end

      # finish him
      SCR.Write(path(".isdn"), nil)

      # clean up variables
      devs = Builtins.filter(@DeletedDevices) do |x|
        !Builtins.regexpmatch(x, isdntyp)
      end
      Builtins.y2debug("DeletedDevices: %1 devs: %2", @DeletedDevices, devs)
      @DeletedDevices = deep_copy(devs)

      true
    end

    # Write one Devices to file
    # @return true if success
    def WriteOneISDNConfig(contr)
      Builtins.y2debug("Devices=%1", @Devices)
      sysconfig = "/etc/sysconfig/isdn"

      Builtins.maplist(@Devices) do |typ, devsmap|
        Builtins.maplist(
          Convert.convert(devsmap, :from => "map", :to => "map <string, map>")
        ) do |num, devmap|
          dev = Ops.add(typ, num)
          next if contr != dev
          p = Ops.add(
            Ops.add(Ops.add(Ops.add(".isdn.value.\"", sysconfig), "/cfg-"), dev),
            "\"."
          )
          # write all keys to config
          Builtins.maplist(
            Convert.convert(
              Map.Keys(devmap),
              :from => "list",
              :to   => "list <string>"
            )
          ) do |k|
            next if k == "module" || k == "options"
            SCR.Write(
              Builtins.topath(Ops.add(p, k)),
              Ops.get_string(devmap, k, "")
            )
          end
        end
      end

      # finish him
      SCR.Write(path(".isdn"), nil)

      true
    end
  end
end
