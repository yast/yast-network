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
  end
end
