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
# File:	modules/InternetDevices.ycp
# Package:	Network configuration
# Summary:	Internet connection and YOU during the installation
# Authors:	Michal Svec <msvec@suse.cz>
#		Arvin Schnell <arvin@suse.de>
#
require "yast"

module Yast
  class InternetDevicesClass < Module
    def main
      Yast.import "Internet"
      Yast.import "NetworkInterfaces"
    end

    # Reset values.
    def Reset
      Internet.device = ""
      Internet.type = ""
      Internet.logfile = ""
      Internet.provider = ""
      Internet.password = ""
      Internet.demand = false
      Internet.askpassword = nil
      Internet.capi_adsl = false
      Internet.capi_isdn = false

      nil
    end

    #  Set device from argument as default network device
    def SetDevice(dev)
      Internet.device = dev
      NetworkInterfaces.Select(Internet.device)
      Internet.type = NetworkInterfaces.FastestType(Internet.device)
      Internet.provider = Ops.get_string(
        NetworkInterfaces.Current,
        "PROVIDER",
        ""
      )

      if Internet.provider != ""
        Yast.import "Provider"

        Provider.Read
        Provider.Select(Internet.provider)

        Internet.demand = Ops.get_string(Provider.Current, "DEMAND", "no") == "yes"
        Internet.password = Ops.get_string(Provider.Current, "PASSWORD", "")
        Internet.askpassword = Ops.get_string(
          Provider.Current,
          "ASKPASSWORD",
          "no"
        ) == "yes"
        Internet.capi_adsl = Ops.get_string(
          Provider.Current,
          "PPPMODE",
          "pppoe"
        ) == "capi-adsl"
        Internet.capi_isdn = Ops.get_string(Provider.Current, "PPPMODE", "ippp") == "capi-isdn"
      end

      nil
    end

    # Find the fastest connection to the Internet
    # @return true if a "good" connection was found
    def FindFastest
      Reset()

      NetworkInterfaces.Read
      Internet.device = NetworkInterfaces.Fastest

      if Internet.device == ""
        Internet.device = Ops.get(Internet.GetDevices, 0, "")
      end

      Builtins.y2milestone("fastest=%1", Internet.device)

      # No fallback since there are devices that must not be tested (e.g. lo)
      return false if Internet.device == ""

      SetDevice(Internet.device)
      true
    end

    publish :function => :SetDevice, :type => "void (string)"
    publish :function => :FindFastest, :type => "boolean ()"
  end

  InternetDevices = InternetDevicesClass.new
  InternetDevices.main
end
