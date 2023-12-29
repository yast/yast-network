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

require "yast"
require "cwm/common_widgets"
require "y2network/widgets/port_items"

Yast.import "Label"
Yast.import "Lan"
Yast.import "Popup"
Yast.import "UI"

module Y2Network
  module Widgets
    class BridgePorts < CWM::MultiSelectionBox
      include PortItems

      # @param [Y2Network::InterfaceConfigBuilders::Bridge] settings
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def label
        _("Bridged Devices")
      end

      def help
        # TODO: write it
        ""
      end

      # Default function to init the value of port devices box for bridging.
      def init
        br_ports = @settings.ports
        items = port_items_from(
          @settings.bridgeable_interfaces.map(&:name),
          br_ports,
          Yast::Lan.yast_config # ideally get it from builder?
        )

        # it is list of Items, so cannot use `change_items` helper
        Yast::UI.ChangeWidget(Id(widget_id), :Items, items)
      end

      # Default function to store the value of port devices box.
      def store
        @settings.ports = value
      end

      # Validates created bridge. Currently just prevent the user to create a
      # bridge with already configured interfaces
      #
      # @return true if valid or user decision if not
      def validate
        if @settings.require_adaptation?(value || [])
          Yast::Popup.ContinueCancel(
            _(
              "At least one selected device is already configured.\n" \
              "Adapt the configuration for bridge?\n"
            )
          )
        else
          true
        end
      end
    end
  end
end
