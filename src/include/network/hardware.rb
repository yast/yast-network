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
# File:  modules/ISDN.ycp
# Package:  Network configuration
# Summary:  ISDN data
# Authors:  Michal Svec  <msvec@suse.cz>
#    Karsten Keil <kkeil@suse.de>
#
#
# Representation of the configuration of ISDN.
# Input and output routines.
module Yast
  module NetworkHardwareInclude
    def initialize_network_hardware(include_target)
      textdomain "network"

      Yast.import "Arch"
      Yast.import "Confirm"
      Yast.import "Map"
      Yast.include include_target, "network/routines.rb"
    end

    # Select the given hardware item or clean up structures (item == nil)
    # @param [Fixnum] which item to be chosen
    def FindHardware(hardware, which)
      sel = {}

      if !which.nil?
        sel = Ops.get_map(hardware, which, {})

        if Ops.greater_than(which, Builtins.size(hardware)) ||
            Ops.less_than(which, 0)
          Builtins.y2error(
            "Item not found in Hardware: %1 (%2)",
            which,
            Builtins.size(hardware)
          )
        end
      end

      sel
    end

    # Select the given hardware item
    # SelectHardware is a "virtual method", that is named SelectHW in "subclasses"
    # like Lan and Modem.
    # @param [Hash] sel item to be chosen
    def SelectHardwareMap(sel)
      sel = deep_copy(sel)
      # common stuff
      @description = Ops.get_string(sel, "name", "")
      @type = Ops.get_string(sel, "type", "eth")
      @hotplug = Ops.get_string(sel, "hotplug", "")

      #    unique = sel["udi"]:"";
      @Requires = Ops.get_list(sel, "requires", [])
      # #44977: Requires now contain the appropriate kernel packages
      # but they are handled differently due to multiple kernel flavors
      # (see Package::InstallKernel)
      # Leave only those not starting with "kernel".
      @Requires = Builtins.filter(@Requires) do |r|
        Builtins.search(r, "kernel") != 0
      end
      Builtins.y2milestone("requires=%1", @Requires)

      # FIXME: devname
      @hotplug = ""

      deep_copy(sel)
    end

    # Select the given hardware item or clean up structures (item == nil)
    # @param [Fixnum] which item to be chosen
    def SelectHardware(hardware, which)
      SelectHardwareMap(FindHardware(hardware, which))
    end
  end
end
