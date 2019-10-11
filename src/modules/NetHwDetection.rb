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
# File:  modules/NetHwDetection.ycp
# Package:  Network configuration
# Summary:  Network detection
# Authors:  Michal Svec <msvec@suse.cz>
#
#
# <p>Detects network settings, using dhcp or sniffing network traffic</p>
#
# <h3>Detection process:</h3>
# <h4>Initial stage:</h4><ul>
#   <li>hardware detection
#   <li>load kernel modules (if not already active *1)
#   <li>set up interface (if not already set up *2)
#   <li>run detection
# </ul>
# <h4>Final stage:</h4><ul>
#   <li>read detection data
#   <li>shut down interfaces (if set up before, see *2)
#   <li>remove kernel modules (if loaded before, see *1)
# </ul>
#
# <p>
# <h4>Used software:</h4><ul>
#   <li>dhcpcd(8)
#   <li>netprobe(8) (currently not, originally by Caldera, license unclear)
# </ul>
#
# <p>
# <h4>Usage:</h4><ul>
#   <li>Detection::Start() somewhere at the start of installation
# </ul><p>Later at the module:<ul>
#   <li>if(Detection::running) Detection::Stop();
#   <li>string gw = Detection::result["GATEWAY"]:"";
# </ul>
#
require "yast"
require "shellwords"

module Yast
  class NetHwDetectionClass < Module
    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Directory"
      Yast.import "Package"
      Yast.import "String"

      # yuck, FIXME
      # this is here just because network/hardware.ycp references it
      # because of detection and module loading (StartEthInterface)
      # general stuff
      @description = ""
      @type = ""
      @unique = ""
      @hotplug = ""
      @Requires = []

      Yast.include self, "network/hardware.rb"

      # Detection result
      # (in dhcpcd-<i>interface</i>.info format)
      @result = {}

      # True, if detection is running
      @running = false

      @tmpdir = Directory.tmpdir

      @detection_modules = []
    end

    # Set up the first eth interface, if not already running
    # WATCH OUT, this is the place where modules are loaded
    # @return true if success
    def LoadNetModules
      Builtins.y2milestone("Network detection prepare")

      hardware = ReadHardware("netcard")

      Builtins.y2debug("Hardware=%1", hardware)
      return false if Ops.less_than(Builtins.size(hardware), 1)

      needed_modules = Builtins.listmap(hardware) do |h|
        # Formerly we simply modprobed the first module of the first
        # driver, if it was not already loaded.  But if the user
        # configured the card to use the second driver and unloads it
        # and wants to load the first, it will not work because the
        # first driver is already loaded but not bound to the device
        # (the second one took it). N#59794#c31
        # We will only load a driver if there's no driver for the card active.
        active_driver = Builtins.find(Ops.get_list(h, "drivers", [])) do |d|
          Ops.get_boolean(d, "active", false)
        end
        { Ops.get_string(h, "module", "") => active_driver.nil? }
        # TODO: list of todos
        # 1: choose which driver to load
        # 2: load all its modules: no cards use multiple modules
        # 3: either modprobe or insmod: ISA history
      end
      needed_modules = Builtins.filter(needed_modules) do |m, load|
        load && !m.nil? && m != "" &&
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat("/usr/bin/grep ^%1 /proc/modules", m.shellescape)
          ) != 0
      end
      @detection_modules = Builtins.maplist(needed_modules) { |m, _a| m }
      Package.InstallKernel(Builtins.maplist(@detection_modules) do |m|
        Ops.add(m, ".ko")
      end)
      Builtins.foreach(@detection_modules) do |mod|
        Builtins.y2milestone("Loading module: %1", mod)
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("/usr/sbin/modprobe --use-blacklist %1 2>&1", mod.shellescape)
        )
      end

      Builtins.y2milestone("Network detection prepare (end)")

      true
    end

    # Start the detection
    # @return true on success
    def Start
      if @running == true
        Builtins.y2error("Detection already running")
        return false
      end

      Builtins.y2milestone(
        "IFCONFIG1: %1",
        SCR.Execute(path(".target.bash_output"), "/usr/sbin/ip addr show")
      )
      ret = false
      if LoadNetModules()
        @running = true
        ret = true
      end

      Builtins.y2milestone(
        "IFCONFIG2: %1",
        SCR.Execute(path(".target.bash_output"), "/usr/sbin/ip addr show")
      )
      Builtins.y2milestone("Detection start result: %1", ret)
      ret
    end

    # Stop the detection
    # @return true on success
    def Stop
      if @running != true
        Builtins.y2error("Detection not running")
        return false
      end
      @running = false

      Builtins.y2milestone(
        "IFCONFIG3: %1",
        SCR.Execute(path(".target.bash_output"), "/usr/sbin/ip addr show")
      )

      Builtins.y2milestone("Detection stop ")
      true
    end

    # Duplicate IP detection
    # @param [String] ip tested IP address
    # @return true if duplicate found
    # @see arping(8), ip(8)
    def DuplicateIP(ip)
      # missing param for arping. Arping does nothing in such case only
      # floods logs.
      return false if ip.nil? || ip.empty?

      command = "LC_ALL=C /usr/sbin/ip link show | /usr/bin/grep BROADCAST | " \
        "/usr/bin/grep -v NOARP | /usr/bin/cut -d: -f2"
      exe = SCR.Execute(path(".target.bash_output"), command)
      ifs = Ops.get_string(exe, "stdout", "")
      ifsl = Builtins.filter(Builtins.splitstring(ifs, " \t\n")) { |i| i != "" }

      # #45169: must only probe the interface being set up
      # but I don't know which one it is :-(
      # so pretend there are no dups if we have more interfaces
      return false if Ops.greater_than(Builtins.size(ifsl), 1)

      # find the interface that detects the dup
      ifc = Builtins.find(ifsl) do |ifname|
        # no need to be quiet, diagnostics is good
        command = "/usr/sbin/arping  -D -c2 -w3 -I#{ifname.shellescape} #{ip.shellescape}"
        # 0 no dup, 1 dup, 2 other error (eg. ifc not up, #182473)
        SCR.Execute(path(".target.bash"), command) == 1
      end

      !ifc.nil?
    end

    # this function is moved here just to kee it out of the tangle of
    # includes which will be torn apart in the next release. dependency
    # hell.
    # Resolve IP to hostname
    # @param [String] ip given IP address
    # @return resolved host
    def ResolveIP(ip)
      # quick check to avoid timeout
      if Builtins.size(ip) == 0 ||
          Convert.to_integer(
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat("/usr/bin/grep -q %1 /etc/hosts", ip.shellescape)
            )
          ) != 0
        return ""
      end

      command = "/usr/bin/getent hosts #{ip.shellescape} | /usr/bin/sed \"s/^[0-9.: \t]\\+//g\""
      getent = SCR.Execute(path(".target.bash_output"), command)
      hnent = Ops.get_string(getent, "stdout", "")
      Builtins.y2debug("%1", hnent)
      hnent = String.FirstChunk(hnent, " \t\n")
      hnent = "" if hnent.nil?
      Builtins.y2debug("'%1'", hnent)
      String.CutBlanks(hnent)
    end

    publish variable: :description, type: "string"
    publish variable: :type, type: "string"
    publish variable: :unique, type: "string"
    publish variable: :hotplug, type: "string"
    publish variable: :Requires, type: "list <string>"
    publish variable: :result, type: "map"
    publish variable: :running, type: "boolean"
    publish function: :Start, type: "boolean ()"
    publish function: :Stop, type: "boolean ()"
    publish function: :DuplicateIP, type: "boolean (string)"
    publish function: :ResolveIP, type: "string (string)"
  end

  NetHwDetection = NetHwDetectionClass.new
  NetHwDetection.main
end
