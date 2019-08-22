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

include Yast::UIShortcuts

require "y2network/dialogs/s390_device_activation"

module Yast
  module NetworkLanHardwareInclude
    def initialize_network_lan_hardware(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Arch"
      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "LanItems"
      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/lan/cards.rb"

      @hardware = nil
    end

    # Dynamic initialization of help text.
    #
    # @return content of the help
    def initHelp
      if Arch.s390
        # overwrite help
        # Manual dialog help 5/4
        hw_help = _(
          "<p>Here, set up your networking device. The values will be\nwritten to <i>/etc/modprobe.conf</i> or <i>/etc/chandev.conf</i>.</p>\n"
        ) +
          # Manual dialog help 6/4
          _(
            "<p>Options for the module should be written in the format specified\nin the <b>IBM Device Drivers and Installation Commands</b> manual.</p>"
          )
      end

      hw_help
    end

    # S/390 devices configuration dialog
    # @return dialog result
    def S390Dialog(builder:)
      ret = Y2Network::Dialogs::S390DeviceActivation.run(builder)
      if ret == :next
        configured = builder.configure
        builder.name = builder.configured_interface if configured
        if !configured || builder.name.empty?
          Popup.Error(
            _(
              "An error occurred while creating device.\nSee YaST log for details."
            )
          )

          ret = nil
        end
      end

      ret
    end
  end
end
