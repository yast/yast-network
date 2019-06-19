# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"

module Yast
  # This class creates a summary of the configured lan items supporting
  # different types of summaries.
  class LanItemsSummary
    include I18n

    def initialize
      textdomain "network"
      Yast.import "LanItems"
      Yast.import "Summary"
    end

    # Generates a summary in RichText format for the configured interfaces
    #
    # @example
    #   LanItemsSummary.new.default
    #   => "<ul><li><p>eth0<br>DHCP</p></li><li><p>eth1<br>NONE</p></li></ul>"
    #
    # @see Summary
    # @return [String] summary in RichText
    def default
      items = []

      LanItems.Items.each do |item, conf|
        next if !Yast::LanItems.IsItemConfigured(item)

        ifcfg = LanItems.GetDeviceMap(item) || {}
        items << Summary.Device(conf["ifcfg"], ifcfg_protocol(ifcfg))
      end

      return Summary.NotConfigured if items.empty?

      Summary.DevicesList(items)
    end

    # Generates a summary in RichText format for the configured interfaces
    #
    # @example
    #   LanItemsSummary.new.proposal
    #   => "<ul><li><p>Configured with DHCP: eth0, eth1<br></p></li>" \
    #      "<li><p>br0 (Bridge)<br>IP address: 192.168.122.60/24" \
    #      "<br>Bridge Ports: eth2 eth3</p></li></ul>"
    #
    # @see Summary
    # @return [String] summary in RichText
    def proposal
      items = []
      config = Y2Network::Config.find(:yast)

      items << "<li>#{dhcp_summary}</li>" unless LanItems.find_dhcp_ifaces.empty?
      items << "<li>#{static_summary}</li>" unless LanItems.find_static_ifaces.empty?
      items << "<li>#{bridge_summary}</li>" unless config.interfaces.by_type("br").empty?
      items << "<li>#{bonding_summary}</li>" unless config.interfaces.by_type("bond").empty?

      return Summary.NotConfigured if items.empty?

      Summary.DevicesList(items)
    end

    # Generates a one line text summary for the configured interfaces.
    #
    # @example with one configured interface
    #   LanItemsSummary.new.one_line
    #   => "DHCP / eth1"
    #
    # @example with many configured interfaces
    #   LanItemsSummary.new.one_line
    #   => "Multiple Interfaces"
    #
    # @return [String] summary in just one line and in plain text
    def one_line
      protocols  = []
      configured = []
      output     = []

      Yast::LanItems.Items.each do |item, conf|
        next if !LanItems.IsItemConfigured(item)

        ifcfg = LanItems.GetDeviceMap(item) || {}
        protocols << ifcfg_protocol(ifcfg)

        configured << conf["ifcfg"]
      end

      output << protocols.first if protocols.uniq.size == 1

      case configured.size
      when 0
        return Summary.NotConfigured
      when 1
        output << configured.join(", ")
      else
        # TRANSLATORS: informs that multiple interfaces are configured
        output << _("Multiple Interfaces")
      end

      output.join(" / ")
    end

  private

    def ifcfg_protocol(ifcfg)
      protocol = LanItems.DeviceProtocol(ifcfg)

      if protocol =~ /DHCP/
        "DHCP"
      elsif IP.Check(protocol)
        "STATIC"
      else
        LanItems.DeviceProtocol(ifcfg)
      end
    end

    # Return a summary of the interfaces configurew with DHCP
    #
    # @return [String] interfaces configured with DHCP summary
    def dhcp_summary
      # TRANSLATORS: %s is the list of interfaces configured by DHCP
      _("Configured with DHCP: %s") % LanItems.find_dhcp_ifaces.sort.join(", ")
    end

    # Return a summary of the interfaces configured statically
    #
    # @return [String] statically configured interfaces summary
    def static_summary
      # TRANSLATORS: %s is the list of interfaces configured by DHCP
      _("Statically configured: %s") % LanItems.find_static_ifaces.sort.join(", ")
    end

    # Return a summary of the configured bridge interfaces
    #
    # @return [String] bridge configured interfaces summary
    def bridge_summary
      config = Y2Network::Config.find(:yast)
      _("Bridges: %s") % config.interfaces.by_type("br").map do |n|
        "#{n} (#{config.interfaces.bridge_slaves(n.name).sort.join(", ")})"
      end
    end

    # Return a summary of the configured bonding interfaces
    #
    # @return [String] bonding configured interfaces summary
    def bonding_summary
      config = Y2Network::Config.find(:yast)
      _("Bonds: %s") % config.interfaces.by_type("bond").map do |n|
        "#{n} (#{config.interfaces.bond_slaves(n.name).sort.join(", ")})"
      end
    end
  end
end
