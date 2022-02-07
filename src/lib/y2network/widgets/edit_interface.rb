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
require "y2network/sequences/interface"
require "y2network/s390_group_device"
require "y2network/dialogs/s390_device_activation"

Yast.import "Label"
Yast.import "Lan"

module Y2Network
  module Widgets
    class EditInterface < CWM::PushButton
      # @param table [InterfacesTable]
      def initialize(table)
        textdomain "network"

        @table = table
      end

      # @see CWM::AbstractWidget#init
      def init
        disable unless @table.value
      end

      def label
        Yast::Label.EditButton
      end

      def handle
        config = Yast::Lan.yast_config.copy
        connection_config = config.connections.by_name(@table.value)
        item = connection_config || selected_interface(config)

        builder = Y2Network::InterfaceConfigBuilder.for(item.type, config: connection_config)
        builder.name = item.name

        if item.is_a?(Y2Network::S390GroupDevice)
          builder.device_id = builder.name
          activation_dialog = Y2Network::Dialogs::S390DeviceActivation.for(builder)
          return :redraw if activation_dialog.run != :next
        end

        Y2Network::Sequences::Interface.new.public_send(:edit, builder)
        :redraw
      end

      def selected_interface(config)
        config.interfaces.by_name(@table.value) || config.s390_devices.by_id(@table.value)
      end

      def help
        # TRANSLATORS: Help for 'Edit' interface configuration button
        _(
          "<p><b><big>Configuring:</big></b><br>\n" \
          "Choose a network card to change.\n" \
         "Then press <b>Edit</b>.</p>\n"
        )
      end
    end
  end
end
