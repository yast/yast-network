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
require "y2network/presenters/interface_status"

Yast.import "Summary"
Yast.import "HTML"

module Y2Network
  module Presenters
    # This class converts a connection config configuration object into a string to be used
    # in an AutoYaST summary or in a table.
    class InterfaceSummary
      include Yast::I18n
      include InterfaceStatus

      # @return [String]
      attr_reader :name

      # Constructor
      #
      # @param name [String] name of device to describe
      # @param config [Y2Network::Config]
      def initialize(name, config)
        textdomain "network"
        @name = name
        @config = config
      end

      def text
        interface = @config.interfaces.by_name(@name)
        hardware = interface ? interface.hardware : nil
        descr = hardware ? hardware.description : ""

        config = @config.connections.by_name(@name)
        bullets = []
        rich = ""

        if config
          descr = config.name if descr.empty?

          status = status_info(config)

          bullets << _("Device Name: %s") % config.name
          bullets << status
          bullets << config.startmode.long_description
          bullets += aliases_info(config)

          if config.type.bonding?
            label = _("Bonding Slaves")
            bullets << "#{label}: #{config.slaves.join(" ")}"
          elsif config.type.bridge?
            label = _("Bridge Ports")
            bullets << "#{label}: #{config.ports.join(" ")}"
          end

          master = config.find_master(@config.connections)
          if master
            master_desc = if master.type.bonding?
              _("Bonding master")
            else
              _("Bridge")
            end
            bullets << format("%s: %s", master_desc, master.name)
          end
        end

        if hardware.nil? || !hardware.exists?
          rich << "<b>(" << _("No hardware information") << ")</b><br>"
        else
          rich << "<b>(" << _("Not connected") << ")</b><br>" if !hardware.link
          rich << "<b>MAC : </b>" << hardware.mac << "<br>" if hardware.mac
          rich << "<b>BusID : </b>" << hardware.busid << "<br>" if hardware.busid
          # TODO: physical port id. Probably in hardware?
        end

        rich = Yast::HTML.Bold(descr) + "<br>" + rich
        if config
          rich << Yast::HTML.List(bullets)
        else
          if hardware && hardware.name && !hardware.name.empty?
            dev_name = _("Device Name: %s") % hardware.name
            rich << Yast::HTML.Bold(dev_name) << "<br>"
          end

          rich << "<p>"
          rich << _("The device is not configured. Press <b>Edit</b>\nto configure.\n")
          rich << "</p>"
        end
        rich
      end

    private

      def aliases_info(config)
        config.ip_aliases.map do |alias_|
          "#{alias_.address} (#{alias_.label})"
        end
      end
    end
  end
end
