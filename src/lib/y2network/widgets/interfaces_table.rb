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
      def initialize(description)
        textdomain "network"

        @description = description
      end

      def header
        [
          _("Name"),
          _("IP Address"),
          _("Device"),
          _("Note")
        ]
      end

      def opt
        [:notify, :immediate]
      end

      def handle
        @description.value = create_description

        nil
      end

      def items
        # TODO: unconfigured devices
        config = Yast::Lan.yast_config
        # TODO: handle unconfigured
        config.interfaces.map do |interface|
          conn = config.connections.by_name(interface.name)
          [
            interface.name, # first is ID in table
            interface.name, # TODO: better name based on hwinfo?
            interface_protocol(conn),
            interface.name,
            ""
          ]
        end
      end

      # Workaround for usage in old CWM which also cache content of cwm items
      def init
        change_items(items)
        handle
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

      def create_description
        interface = Yast::Lan.yast_config.interfaces.by_name(value)
        hwinfo = interface.hardware
        result = ""
        if !hwinfo.exists?
          result << "<b>(" << _("No hardware information") << ")</b><br>"
        else
          if !hwinfo.link
            result << "<b>(" << _("Not connected") << ")</b><br>"
          end
          if !hwinfo.mac.empty?
            result << "<b>MAC : </b>" << hwinfo.mac << "<br>"
          end
          if !hwinfo.busid.empty?
            result << "<b>BusID : </b>" << hwinfo.busid << "<br>"
          end
        end

        result
      end
    end
  end
end
