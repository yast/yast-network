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
require "cwm/table"


module Y2Network
  module Widgets
    class InterfacesTable < CWM::Table
      def initialize
        textdomain "network"
      end

      def header
        [
          _("Name"),
          _("IP Address"),
          _("Device"),
          _("Note")
        ]
      end

      def items
        # TODO: unconfigured devices
        config = Yast::Lan.yast_config.copy
        # TODO: handle unconfigured
        config.connections.map do |conn|
          [
            conn.name, # first is ID in table
            conn.name, # TODO: better name based on hwinfo?
            interface_protocol(conn),
            conn.interface,
            ""
          ]
        end
      end

      # Workaround for usage in old CWM which also cache content of cwm items
      def init
        change_items(items)
      end

    private

      def interface_protocol(connection)
        return _("Not configured") if connection.nil?

        bootproto = connection.bootproto.name

        if bootproto == "static"
          connection.ip.to_s
        else
          bootproto.upcase
        end
      end
    end
  end
end
