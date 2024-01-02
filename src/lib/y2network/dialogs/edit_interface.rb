# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "cwm/dialog"

require "y2network/widgets/address_tab"
require "y2network/widgets/bond_ports_tab"
require "y2network/widgets/bridge_ports_tab"
require "y2network/widgets/general_tab"
require "y2network/widgets/hardware_tab"
require "y2network/widgets/wireless_tab"

Yast.import "Label"

module Y2Network
  module Dialogs
    # Dialog to Edit Interface. Content of the dialog heavily depends on the interface type and
    # change of type is not allowed after dialog creation.
    class EditInterface < CWM::Dialog
      # @param settings [InterfaceBuilder] object holding interface configuration
      #   modified by the dialog.
      def initialize(settings)
        super()
        @settings = settings

        textdomain "network"
      end

      def title
        _("Network Card Setup")
      end

      def contents
        # if there is addr, make it initial unless for wifi, where first one should be wifi specific
        # configs
        addr_tab = Widgets::AddressTab.new(@settings)
        addr_tab.initial = true unless @settings.type.wireless?

        tabs = case @settings.type.short_name
        when "vlan", "dummy"
          [Widgets::GeneralTab.new(@settings), addr_tab]
        when "tun", "tap"
          [addr_tab]
        when "br"
          [Widgets::GeneralTab.new(@settings), addr_tab, Widgets::BridgePorts.new(@settings)]
        when "bond"
          [Widgets::GeneralTab.new(@settings), addr_tab, Widgets::BondPortsTab.new(@settings)]
        when "wlan"
          wireless = Widgets::WirelessTab.new(@settings)
          wireless.initial = true
          [Widgets::GeneralTab.new(@settings), wireless, addr_tab,
           Widgets::HardwareTab.new(@settings)]
        else
          [Widgets::GeneralTab.new(@settings), addr_tab, Widgets::HardwareTab.new(@settings)]
        end

        VBox(CWM::Tabs.new(*tabs))
      end

      # abort is just cancel as this is a sub dialog
      def abort_button
        Yast::Label.CancelButton
      end

      # removes back button when editing device, but keep it when this dialog follows adding
      # new interface
      def back_button
        @settings.newly_added? ? Yast::Label.BackButton : ""
      end
    end
  end
end
