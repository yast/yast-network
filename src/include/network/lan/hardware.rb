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
# File:	include/network/lan/hardware.ycp
# Package:	Network configuration
# Summary:	Hardware dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#

require "y2network/dialogs/s390_device_activation"

module Yast
  module NetworkLanHardwareInclude
    def initialize_network_lan_hardware(include_target)
      textdomain "network"

      Yast.import "Arch"
    end

    # S/390 devices configuration dialog
    # @return dialog result
    def S390Dialog(builder:)
      dialog = Y2Network::Dialogs::S390DeviceActivation.for(builder)
      dialog ? dialog.run : :abort
    end
  end
end
