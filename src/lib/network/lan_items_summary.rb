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

      items << "<li>#{dhcp_summary}</li>" unless dhcp_ifaces.empty?
      static_ifaces.each do |name|
        items << Summary.Device(summary_label_for(name), summary_details_for(name))
      end

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

    # Return the label name for the given interface
    #
    # @param name [String] interface name
    # @return [String] label name for the given interfave
    def summary_label_for(name)
      case NetworkInterfaces.GetType(name)
      when "br"
        # TRANSLATORS: %s is the bridge interface name
        _("%s (Bridge)") % name
      when "bond"
        # TRANSLATORS: %s is the bonding interface name
        _("%s (Bonding Master)") % name
      else
        name
      end
    end

    # Return extra details for the interfave given like the ip address and also
    # the slaved interfaces in case of a bridge or a bond device.
    #
    # @param name [String] interface name
    # @return [String] interface summary details
    def summary_details_for(name)
      dev_map = NetworkInterfaces.devmap(name)
      output = LanItems.ip_overview(dev_map).first
      type = NetworkInterfaces.GetType(name)
      output += "<br>#{LanItems.slaves_desc(type, name)}" if ["br", "bond"].include?(type)

      output
    end

    # Return a summary of the interfaces configurew with DHCP
    #
    # @return [String] interfaces configured with DHCP summary
    def dhcp_summary
      # TRANSLATORS: %s is the list of interfaces configured by DHCP
      _("Configured with DHCP: %s") % dhcp_ifaces.join(", ")
    end

    # Convenience method that obtains the list of dhcp configured interfaces
    #
    # @return [Array<String>] dhcp configured interface names
    def dhcp_ifaces
      LanItems.find_dhcp_ifaces
    end

    # Convenience method that obtains the list of static configured interfaces
    #
    # @return [Array<String>] static configured interface names
    def static_ifaces
      LanItems.find_static_ifaces
    end
  end
end
