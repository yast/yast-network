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

      def label
        Yast::Label.EditButton
      end

      def handle
        config = Yast::Lan.yast_config.copy
        # TODO: handle unconfigured
        connection_config = config.connections.by_name(@table.value)
        builder = Y2Network::InterfaceConfigBuilder.for(connection_config.type, config: connection_config)
        builder.name = connection_config.name
        Y2Network::Sequences::Interface.new.edit(builder)
        :redraw
      end
    end
  end
end
