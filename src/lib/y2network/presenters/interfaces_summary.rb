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
require "y2network/interface_type"

Yast.import "Summary"
Yast.import "HTML"

module Y2Network
  module Presenters
    # This class converts a connection config configurations into a string to be used
    # in an AutoYaST summary.
    class InterfacesSummary
      include Yast::I18n
      include Yast::Logger
      include InterfaceStatus

      # @return [Config]
      attr_reader :config

      def initialize(config)
        textdomain "network"

        @config = config
      end

      def text
        overview = config.interfaces.map do |interface|
          connection = config.connections.by_name(interface.name)
          descr = interface.hardware ? interface.hardware.description : ""
          descr = interface.name if descr.empty?
          status = connection ? status_info(connection) : Yast::Summary.NotConfigured
          Yast::Summary.Device(descr, status)
        end

        Yast::Summary.DevicesList(overview)
      end

      # Generates a one line text summary for the configured interfaces.
      #
      # @example with one configured interface
      #   presenter.one_line_text
      #   => "DHCP / eth1"
      #
      # @example with many configured interfaces
      #   presenter.one_line_text
      #   => "Multiple Interfaces"
      #
      # @return [String] summary in just one line and in plain text
      def one_line_text
        protocols = []
        output = []

        protocols << "DHCP" if config.connections.any?(&:dhcp?)
        protocols << "STATIC" if config.connections.any?(&:static?)

        output << protocols.first if protocols.uniq.size == 1

        case config.connections.size
        when 0
          return Yast::Summary.NotConfigured
        when 1
          output << config.connections.first.interface
        else
          output << _("Multiple Interfaces")
        end

        output.join(" / ")
      end

      # Generates a summary in RichText format for the configured interfaces
      #
      # @example
      #   interfaces_summary.proposal_text
      #   => "<ul><li><p>Configured with DHCP: eth0, eth1<br></p></li>" \
      #      "<li><p>br0 (Bridge)<br>IP address: 192.168.122.60/24" \
      #      "<br>Bridge Ports: eth2 eth3</p></li></ul>"
      #
      # @see Summary
      # @return [String] summary in RichText
      def proposal_text
        items = []
        items << list_item_for(dhcp_summary) unless dhcp_ifaces.empty?
        items << list_item_for(static_summary) unless static_ifaces.empty?
        items << list_item_for(bridge_summary) unless bridge_connections.empty?
        items << list_item_for(bonding_summary) unless bonding_connections.empty?
        items << list_item_for(Yast::Summary.NotConfigured) if items.empty?

        Yast::Summary.DevicesList(items)
      end

      # Return a summary of the interfaces configurew with DHCP
      #
      # @return [String] interfaces configured with DHCP summary
      def dhcp_summary
        # TRANSLATORS: %s is the list of interfaces configured by DHCP
        _("Configured with DHCP: %s") % dhcp_ifaces.sort.join(", ")
      end

      def dhcp_ifaces
        config.connections.select(&:dhcp?).map(&:interface)
      end

      # Return a summary of the interfaces configured statically
      #
      # @return [String] statically configured interfaces summary
      def static_summary
        # TRANSLATORS: %s is the list of interfaces configured by DHCP
        _("Statically configured: %s") % static_ifaces.sort.join(", ")
      end

      # Return a summary of the configured bridge interfaces
      #
      # @return [String] bridge configured interfaces summary
      def bridge_summary
        _("Bridges: %s") % bridge_connections.map do |connection|
          "#{connection.name} (#{connection.ports.sort.join(", ")})"
        end
      end

      # Return a summary of the configured bonding interfaces
      #
      # @return [String] bonding configured interfaces summary
      def bonding_summary
        _("Bonds: %s") % bonding_connections.map do |connection|
          "#{connection.name} (#{connection.slaves.sort.join(", ")})"
        end
      end

    private

      def list_item_for(text)
        "<li>" + text + "</li>"
      end

      def static_ifaces
        config.connections.select(&:static?).map(&:interface)
      end

      def bridge_connections
        config.connections.select { |c| c.type.bridge? }
      end

      def bonding_connections
        config.connections.select { |c| c.type.bonding? }
      end
    end
  end
end
