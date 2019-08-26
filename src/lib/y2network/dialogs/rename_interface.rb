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

require "cwm/popup"
require "y2network/widgets/custom_interface_name"
require "y2network/widgets/rename_hwinfo"

module Y2Network
  module Dialogs
    # This dialog allows the user to rename a network interface
    #
    # Is works in a slightly different way depending on the interface.
    #
    # * For physical interfaces, it allows the user to select between using
    #   the MAC adddress or the Bus ID, which are present in the Hwinfo object
    #   associated to the interface.
    # * For not connected interfaces ({FakeInterface}), as the hardware is not present,
    #   the user must specify the MAC or the Bus ID by hand (NOT IMPLEMENTED YET).
    # * For virtual interfaces, like bridges, only the name can be chaned (no hardware
    #   info at all) (NOT IMPLEMENTED YET).
    class RenameInterface < CWM::Popup
      def initialize(builder)
        textdomain "network"

        @builder = builder
        interface = @builder.interface
        @old_name = interface.name
      end

      # Runs the dialog
      def run
        ret = super
        return unless ret == :ok
        renaming_mechanism, _hwinfo = rename_hwinfo_widget.value
        @builder.rename_interface(name_widget.value, renaming_mechanism)
        name_widget.value
      end

      # @see CWM::CustomWidget
      def contents
        VBox(
          Left(name_widget),
          VSpacing(0.5),
          Frame(
            _("Base Udev Rule On"),
            rename_hwinfo_widget
          )
        )
      end

      # Interface's name widget
      #
      # @return [Y2Network::Widgets::CustomInterfaceName]
      def name_widget
        @name_widget ||= Y2Network::Widgets::CustomInterfaceName.new(@builder)
      end

      # Widget to select the hardware information to base the rename on
      #
      # @return [Y2Network::Widgets::RenameHwinfo]
      def rename_hwinfo_widget
        @rename_hwinfo_widget ||= Y2Network::Widgets::RenameHwinfo.new(@builder)
      end
    end
  end
end
