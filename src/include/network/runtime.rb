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
# File:	include/network/runtime.ycp
# Package:	Network configuration
# Summary:	Runtime routines
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkRuntimeInclude
    def initialize_network_runtime(include_target)

      Yast.import "Arch"
      Yast.import "Desktop"
      Yast.import "ISDN"
      Yast.import "Mode"
      Yast.import "NetworkInterfaces"
      Yast.import "Package"
      Yast.import "Service"
      Yast.import "PackageSystem"

      textdomain "network"
    end

    # Run SuSEconfig
    # @return true if success
    def RunSuSEconfig
      Builtins.y2milestone("Updating sendmail and/or postfix configuration.")
      SCR.Execute(
        path(".target.bash"),
        "/usr/lib/sendmail.d/update 2>/dev/null"
      )
      SCR.Execute(path(".target.bash"), "/usr/sbin/config.postfix 2>/dev/null")
      true
    end

    # Link detection
    # @return true if link found
    # @see #ethtool(8)
    def HasLink
      ifname = "eth0"

      command = Builtins.sformat(
        "ethtool %1 | grep -q 'Link detected: no'",
        ifname
      )
      if Convert.to_integer(SCR.Execute(path(".target.bash"), command)) == 1
        return false
      end
      true
    end

    # Are there interfaces controlled by smpppd and qinternet?
    # They are the ones with USERCONTROL=yes (#44303)
    # @return true/false
    def HaveDialupLikeInterfaces
      devs = NetworkInterfaces.Locate("USERCONTROL", "yes")
      Builtins.y2milestone("user controlled interfaces: %1", devs)
      return true if devs != []

      devs = ISDN.Locate("USERCONTROL", "yes")
      Builtins.y2milestone("user controlled ISDN interfaces: %1", devs)

      devs != []
    end

    # Setup smpppd(8)
    # @return true if success
    def SetupSMPPPD(install_force)
      ret = true
      # Stop and disable
      if !HaveDialupLikeInterfaces()
        ret = Service.Disable("smpppd") && ret
        ret = Service.Stop("smpppd") && ret
      else
        # (#299033) - if not forced, user can continue also without packages
        ret = PackageSystem.CheckAndInstallPackagesInteractive(["smpppd"])

        ret = Service.Enable("smpppd") && ret

        # Installation?
        if Mode.normal
          if Service.Status("smpppd") == 0
            ret = Service.Reload("smpppd") && ret
          else
            ret = Service.Start("smpppd") && ret
          end
        end
      end

      ret
    end
  end
end
