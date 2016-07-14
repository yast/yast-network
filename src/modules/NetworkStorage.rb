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
    include Logger

    def main
      Yast.import "Storage"
    end

    # Ask /proc/mounts what device a mount point is using.
    # @return e.g. /dev/sda2 (or just "nfs")
    def getDevice(mount_point)
      log.info "The mount_point is #{mount_point}"
      out = SCR.Read(path(".proc.mounts")).find do |m|
        m["file"] == mount_point && m["vfstype"] != "rootfs"
      end
      return "" unless out
      log.info "mounpoint found #{out}"
      device = case out["vfstype"]
      when "nfs", "nfs4"
        "nfs"
      else
        out["spec"]
      end

      log.info "#{mount_point} is on device #{device}"
      device
    end

    publish function: :getDevice, type: "string (string)"
  end

  NetworkStorage = NetworkStorageClass.new
  NetworkStorage.main
end
