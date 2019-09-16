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
# File:	include/network/lan/address.ycp
# Package:	Network configuration
# Summary:	Network card adresss configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
require "y2firewall/helpers/interfaces"
require "y2network/dialogs/edit_interface"
require "y2network/boot_protocol"

module Yast
  module NetworkLanAddressInclude
    include Y2Firewall::Helpers::Interfaces
    include Yast::Logger
    include Yast::I18n

    def initialize_network_lan_address(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "ProductFeatures"

      Yast.include include_target, "network/lan/help.rb"
      Yast.include include_target, "network/lan/hardware.rb"
      Yast.include include_target, "network/complex.rb"
      Yast.include include_target, "network/lan/s390.rb"

      @force_static_ip = ProductFeatures.GetBooleanFeature(
        "network",
        "force_static_ip"
      )
    end

    # Dialog for setting up IP address
    # @return dialog result
    def AddressDialog(builder:)
      @builder = builder

      ret = Y2Network::Dialogs::EditInterface.run(builder)
      log.info "ShowAndRun: #{ret}"

      if ret != :back && ret != :abort
        if LanItems.isCurrentDHCP && !LanItems.isCurrentHotplug
          # fixed bug #73739 - if dhcp is used, dont set default gw statically
          # but also: reset default gw only if DHCP* is used, this branch covers
          #		 "No IP address" case, then default gw must stay (#460262)
          # and also: don't delete default GW for usb/pcmcia devices (#307102)
          yast_config = Y2Network::Config.find(:yast)
          if yast_config && yast_config.routing && yast_config.routing.default_route
            remove_gw = Popup.YesNo(
              _(
                "A static default route is defined.\n" \
                "It is suggested to remove the static default route definition \n" \
                "if one can be obtained also via DHCP.\n" \
                "Do you want to remove the static default route?"
              )
            )
            yast_config.routing.remove_default_routes if remove_gw
          end
        end
      end

      log.info "AddressDialog res: #{ret.inspect}"
      ret
    end
  end
end
