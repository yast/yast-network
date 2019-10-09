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
require "yast2/popup"

Yast.import "Label"
Yast.import "Lan"
Yast.import "Popup"

module Y2Network
  module Widgets
    class DeleteInterface < CWM::PushButton
      # @param table [InterfacesTable]
      def initialize(table)
        textdomain "network"
        @table = table
      end

      def label
        Yast::Label.DeleteButton
      end

      def handle
        config = Yast::Lan.yast_config
        connection_config = config.connections.by_name(@table.value)
        return nil unless connection_config # unconfigured physical device. Delete do nothing

        if connection_config.startmode.name == "nfsroot"
          if !Yast::Popup.YesNoHeadline(
            Yast::Label.WarningMsg,
            _("Device you select has STARTMODE=nfsroot. Really delete?")
          )
            return nil
          end
        end

        others = all_modify(config, connection_config)
        if !others.empty?
          delete, modify = others.partition { |c| c.type.vlan? }
          message = format(_("Device you select has been used in other devices.<br>" \
            "When deleted these devices will be modified<ul>%s</ul><br>" \
            "and these devices deleted: <ul>%s</ul><br>" \
            "Really delete?"),
            modify.map { |m| "<li>#{m.name}</li>" }.join("\n"),
            delete.map { |m| "<li>#{m.name}</li>" }.join("\n"))

          if Yast2::Popup.show(message, richtext: :yes, buttons: :yes_no, headline: :warning) == :no
            return nil
          end
        end

        config.delete_interface(@table.value)

        :redraw
      end

    private

      # @return [Array]
      def all_modify(config, connection_config)
        all = config.connections_to_modify(connection_config).to_a
        vlans = all.select { |c| c.type.vlan? }
        vlans.each_with_object(all) { |c, a| a.concat(all_modify(config, c)) }

        all
      end
    end
  end
end
