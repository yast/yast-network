# Copyright (c) [2019-2021] SUSE LLC
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
require "network/wicked"
require "y2network/presenters/interface_summary"
require "y2network/presenters/s390_group_device_summary"

Yast.import "Lan"
Yast.import "Popup"
Yast.import "UI"

module Y2Network
  module Widgets
    class InterfacesTable < CWM::Table
      include Yast::Wicked

      def initialize(description)
        textdomain "network"

        @description = description
        @handlers = []
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

      def add_handler(handler)
        @handlers << handler
      end

      def handle
        @description.value = create_description
        refresh_handlers

        nil
      end

      def items
        items_list = []
        config.interfaces.each { |i| items_list << interface_item(i) }
        config.s390_devices.select(&:offline?).each do |device|
          items_list << device_item(device)
        end

        items_list
      end

      # Workaround for usage in old CWM which also cache content of cwm items
      def init
        if config.backend?(:network_manager)
          Yast::Popup.Warning(
            _(
              "Network is currently handled by NetworkManager\n" \
              "or completely disabled. YaST is unable to configure some options."
            )
          )
          # switch to global tab
          Yast::UI.FakeUserInput("ID" => "global")
          return
        end

        change_items(items)
        handle
      end

      def help
        _(
          "<p><b><big>Overview</big></b><br>\n" \
           "Obtain an overview of the network interfaces configuration.</p>\n"
        )
      end

    private

      def refresh_handlers
        @handlers.each { |h| h.init }
      end

      def note(interface, conn)
        if interface.name != interface.old_name && interface.old_name
          return format("%s -> %s", interface.old_name, interface.name)
        end

        return "" unless conn

        parent = conn.find_parent(config.connections)

        # TRANSLATORS: %s is a name of a bond/bridge device
        return format(_("included in %s"), parent.name) if parent

        return format(_("parent: %s"), conn.parent_device) if conn.type.vlan?

        ""
      end

      # Constructs device description for inactive s390 devices
      def device_item(device)
        [device.id, description_for(device), _("Not activated"), device.id, ""]
      end

      # Generic device description handler
      def interface_item(interface)
        conn = config.connections.by_name(interface.name)
        [
          # first is (item) ID in table
          interface.name,
          description_for(interface, conn),
          configuration_for(interface, conn),
          interface.name,
          note(interface, conn)
        ]
      end

      def interface_protocol(connection)
        return _("Not Configured") if connection.nil?

        bootproto = connection.bootproto.name

        if bootproto == "static"
          ip_config = connection.ip
          ip_config ? ip_config.address.to_s : ""
        else
          bootproto.upcase
        end
      end

      def configuration_for(interface, connection)
        return interface_protocol(connection) unless connection.nil?

        firmware_configured?(interface) ? _("Configured by firmware") : _("Not Configured")
      end

      def selected_item
        config.interfaces.by_name(value) || config.s390_devices.by_id(value)
      end

      def config
        Yast::Lan.yast_config
      end

      def create_description
        summary = Presenters.const_get("#{summary_class_name}Summary")
        summary.new(value, config).text
      end

      # Returns the connection description if given or the device friendly name if not
      #
      # @param device [Interface, S390GroupDevice] Network device
      # @param conn [ConnectionConfig::Base, nil] Connection configuration
      # @return [String] Connection description if given or the friendly name for the interface (
      #   description or name) if not
      def description_for(device, conn = nil)
        return conn.description unless conn&.description.to_s.empty?

        hwinfo = device.hardware
        (hwinfo&.present?) ? hwinfo.description : device.name
      end

      def summary_class_name
        (selected_item.class.to_s == "Y2Network::S390GroupDevice") ? "S390GroupDevice" : "Interface"
      end

      def firmware_configured?(interface)
        firmware_interfaces.include?(interface.name)
      end
    end
  end
end
