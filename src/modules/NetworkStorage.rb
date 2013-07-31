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
# File:	modules/NetworkStorage.ycp
# Package:	Network configuration
# Summary:	Networked disks
# Authors:	Martin Vidner <mvidner@suse.cz>
#
#
# #176804 - Root on iSCSI installation fails
require "yast"

module Yast
  class NetworkStorageClass < Module
    def main

      Yast.import "Storage"
    end

    # Ask /proc/mounts what device a mount point is using.
    # @return e.g. /dev/sda2 (or just "nfs")
    def getDevice(mount_point)
      cmd = Builtins.sformat(
        "grep ' %1 ' /proc/mounts|grep -v rootfs|tr -d '\n'",
        mount_point
      )
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("mountpoint found %1", out)
      fields = Builtins.splitstring(Ops.get_string(out, "stdout", ""), " ")
      vfstype = Ops.get(fields, 2, "")
      device = vfstype == "nfs" || vfstype == "nfs4" ?
        "nfs" :
        Ops.get(fields, 0, "")
      Builtins.y2milestone("%1 is on device: %2", mount_point, device)
      device
    end

    # If the disk is on a networked device (NFS, ISCSI),
    # the main NIC needs STARTMODE nfsroot instead of auto.
    # @return root dev over network: `no `iscsi `nfs `fcoe
    def isDiskOnNetwork(device)
      Storage.IsDeviceOnNetwork(device)
    end

    def getiBFTDevices
      if SCR.Execute(path(".target.bash"), "ls /sys/firmware/ibft") == 0
        output = Convert.convert(
          SCR.Execute(
            path(".target.bash_output"),
            "ls /sys/firmware/ibft/ethernet*/device/net/"
          ),
          :from => "any",
          :to   => "map <string, any>"
        )
        ifaces = Builtins.filter(
          Builtins.splitstring(Ops.get_string(output, "stdout", ""), "\n")
        ) { |row| Ops.greater_than(Builtins.size(row), 0) }
        return deep_copy(ifaces)
      else
        return []
      end
    end

    publish :function => :getDevice, :type => "string (string)"
    publish :function => :isDiskOnNetwork, :type => "symbol (string)"
    publish :function => :getiBFTDevices, :type => "list <string> ()"
  end

  NetworkStorage = NetworkStorageClass.new
  NetworkStorage.main
end
