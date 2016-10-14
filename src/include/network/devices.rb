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
  module NetworkDevicesInclude
    def initialize_network_devices(_include_target)
      textdomain "network"

      Yast.import "Map"
      Yast.import "NetworkInterfaces"
    end

    # Compute free devices
    # @param [String] type device type
    # @param [Fixnum] num how many free devices return
    # @return num of free devices
    # @example GetFreeDevices("eth", 2) -&gt; [ 1, 2 ]
    def GetFreeDevices(type, num)
      Builtins.y2debug("Devices=%1", @Devices)
      Builtins.y2debug("type,num=%1,%2", type, num)
      Builtins.y2debug("Devices[%1]=%2", type, Ops.get(@Devices, type, {}))

      curdevs = Map.Keys(Ops.get(@Devices, type, {}))
      Builtins.y2debug("curdevs=%1", curdevs)

      i = 0
      count = 0
      ret = []

      # Hotpluggable devices
      if NetworkInterfaces.IsHotplug(type) && !Builtins.contains(curdevs, "")
        Builtins.y2debug("Added simple hotplug device")
        count = Ops.add(count, 1)
        ret = Builtins.add(ret, "")
      end

      # Remaining numbered devices
      while Ops.less_than(count, num)
        ii = Builtins.sformat("%1", i)
        if !Builtins.contains(curdevs, Builtins.sformat("%1%2", type, ii))
          ret = Builtins.add(ret, ii)
          count = Ops.add(count, 1)
        end
        i = Ops.add(i, 1)
      end

      Builtins.y2debug("Free devices=%1", ret)
      deep_copy(ret)
    end

    # Return free device
    # @param [String] type device type
    # @return free device
    # @example GetFreeDevice("eth") -&gt; "1"
    def GetFreeDevice(type)
      Builtins.y2debug("type=%1", type)
      ret = Ops.get(GetFreeDevices(type, 1), 0)
      Builtins.y2error("Free device location error: %1", ret) if ret.nil?
      Builtins.y2debug("Free device=%1", ret)
      ret
    end
  end
end
