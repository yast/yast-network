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

require "y2network/widgets/interface_button"

module Y2Network
  module Widgets
    class EditInterface < InterfaceButton
      def label
        Yast::Label.EditButton
      end

      def handle
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

      def disable?
        return true unless @table.value

        configured_by_firmware?
      end

      def configured_by_firmware?
        return false if connection_config
        return false unless config.backend?(:wicked)

        require "network/wicked"
        singleton_class.include Yast::Wicked
        firmware_interfaces.include?(@table.value)
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
