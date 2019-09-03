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
        config = Yast::Lan.yast_config
        config.interfaces.map do |interface|
          conn = config.connections.by_name(interface.name)
          [
            interface.name, # first is ID in table
            friendly_name(interface),
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
        if hwinfo.nil? || !hwinfo.exists?
          result << "<b>(" << _("No hardware information") << ")</b><br>"
        else
          result << "<b>(" << _("Not connected") << ")</b><br>" if !hwinfo.link
          result << "<b>MAC : </b>" << hwinfo.mac << "<br>" if hwinfo.mac
          result << "<b>BusID : </b>" << hwinfo.busid << "<br>" if hwinfo.busid
        end
        connection = Yast::Lan.yast_config.connections.by_name(value)
        if connection
          result << _("Device Name: %s") % connection.name
          # TODO: start mode description. Ideally in startmode class
          # TODO: ip overview
        else
          result << "<p>" <<
            _("The device is not configured. Press <b>Edit</b>\nto configure.\n") <<
            "</p>"
        end

        result
      end

      # Returns a friendly name for a given interface
      #
      # @param interface [Interface] Network interface
      # @return [String] Friendly name for the interface (description or name)
      def friendly_name(interface)
        hwinfo = interface.hardware
        hwinfo && hwinfo.present? ? hwinfo.description : interface.name
      end
    end
  end
end
