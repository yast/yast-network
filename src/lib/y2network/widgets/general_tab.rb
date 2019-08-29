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
require "cwm/tabs"

# used widgets
require "y2network/widgets/interface_naming"
require "y2network/widgets/startmode"
require "y2network/widgets/ifplugd_priority"
require "y2network/widgets/firewall_zone"
require "y2network/widgets/ipoib_mode"
require "y2network/widgets/mtu"

module Y2Network
  module Widgets
    class GeneralTab < CWM::Tab
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("&General")
      end

      def contents
        ifplugd_widget = IfplugdPriority.new(@settings)
        MarginBox(
          1,
          0,
          VBox(
            MarginBox(
              1,
              0,
              VBox(
                InterfaceNaming.new(@settings),
                Frame(
                  _("Device Activation"),
                  HBox(Startmode.new(@settings, ifplugd_widget), ifplugd_widget, HStretch())
                ),
                VSpacing(0.4),
                Frame(_("Firewall Zone"), HBox(FirewallZone.new(@settings), HStretch())),
                VSpacing(0.4),
                type.infiniband? ? HBox(IPoIBMode.new(@settings)) : Empty(),
                type.infiniband? ? VSpacing(0.4) : Empty(),
                Frame(
                  _("Maximum Transfer Unit (MTU)"),
                  HBox(MTU.new(@settings), HStretch())
                ),
                VStretch()
              )
            )
          )
        )
      end

      def type
        @settings.type
      end
    end
  end
end
