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
# File:	include/network/summary.ycp
# Package:	Network configuration
# Summary:	Summary and overview functions
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# All config settings are stored in a global variable Devices.
# All hardware settings are stored in a global variable Hardware.
# Deleted devices are in the global list DELETED.
module Yast
  module NetworkSummaryInclude
    def initialize_network_summary(_include_target)
      textdomain "network"

      Yast.import "String"
      Yast.import "NetworkInterfaces"
    end

    # Create list of Table items
    # @param [Array<String>] types list of types
    # @param [String] cur current type
    # @return Table items
    def BuildTypesList(types, cur)
      types = deep_copy(types)
      Builtins.maplist(types) do |t|
        Item(Id(t), NetworkInterfaces.GetDevTypeDescription(t, false), t == cur)
      end
    end
  end
end
