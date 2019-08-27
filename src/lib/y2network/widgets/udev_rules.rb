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
require "cwm/custom_widget"
require "y2network/dialogs/rename_interface"

Yast.import "UI"

module Y2Network
  module Widgets
    class UdevRules < CWM::CustomWidget
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def contents
        Frame(
          _("Udev Rules"),
          HBox(
            InputField(Id(:udev_rules_name), Opt(:hstretch, :disabled), _("Device Name"), ""),
            @settings.interface.can_be_renamed? ? change_button : Empty()
          )
        )
      end

      def init
        self.value = @settings.name
      end

      def handle
        self.value = Y2Network::Dialogs::RenameInterface.new(@settings).run

        nil
      end

      def store
        # TODO: nothing to do as done in RenameInterface which looks wrong
      end

      def value=(name)
        Yast::UI.ChangeWidget(Id(:udev_rules_name), :Value, name)
      end

      def value
        Yast::UI.QueryWidget(Id(:udev_rules_name), :Value)
      end

      def help
        _(
          "<p><b>Udev Rules</b> are rules for the kernel device manager that allow\n" \
            "associating the MAC address or BusID of the network device with its name (for\n" \
            "example, eth1, wlan0 ) and assures a persistent device name upon reboot.\n"
        )
      end

    private

      def change_button
        PushButton(Id(:udev_rules_change), _("Change"))
      end
    end
  end
end
