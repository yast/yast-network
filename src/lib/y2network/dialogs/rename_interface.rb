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
require "y2network/widgets/interface_name"
require "y2network/widgets/renaming_mechanism"
require "y2network/virtual_interface"

module Y2Network
  module Dialogs
    # This dialog allows the user to rename a network interface
    #
    # It allows the user to enter a new name and to select the attribute to
    # base the rename on. Supported attributes are MAC address and Bus ID.
    class RenameInterface < CWM::Popup
      # Constructor
      #
      # @param [Y2Network::InterfaceConfigBuilder] Interface configuration builder object
      def initialize(builder)
        textdomain "network"

        @builder = builder
        @old_name = builder.interface.name
      end

      # @see CWM::CustomWidget
      def contents
        VBox(
          Left(name_widget),
          VSpacing(0.5),
          rename_hwinfo_widget
        )
      end

    private

      # Interface name widget
      #
      # @return [Y2Network::Widgets::InterfaceName]
      def name_widget
        @name_widget ||= Y2Network::Widgets::InterfaceName.new(@builder)
      end

      # Widget to select the hardware information to base the rename on
      #
      # @return [Y2Network::Widgets::RenamingMechanism]
      def rename_hwinfo_widget
        @rename_hwinfo_widget ||= Y2Network::Widgets::RenamingMechanism.new(@builder)
      end
    end
  end
end
