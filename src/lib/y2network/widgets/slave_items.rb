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

Yast.import "NetworkInterfaces"

module Y2Network
  module Widgets
    # Mixin to help create a port device (of any kind) list
    module SlaveItems
      include Yast::Logger
      include Yast::I18n

      # Builds content for port configuration dialog (used e.g. when configuring
      # devices included in a bond)
      #
      # @param [Array<String>] slaves             list of device names
      # @param [Array<String>] included_ifaces    list of device names already included in
      #                                           a main device (bond, bridge, ...)
      # @param [ConnectionConfig] config where port devices live
      def slave_items_from(slaves, included_ifaces, config)
        raise ArgumentError, "slaves cannot be nil" if slaves.nil?
        raise ArgumentError, "some interfaces must be selected" if included_ifaces.nil?
        raise ArgumentError, "slaves cannot be empty" if slaves.empty? && !included_ifaces.empty?

        textdomain "network"

        log.debug "creating list of slaves from #{slaves.inspect}"

        slaves.each_with_object([]) do |slave, result|
          interface = config.interfaces.by_name(slave)

          next unless interface

          if interface.type.tun? || interface.type.tap?
            description = Yast::NetworkInterfaces.GetDevTypeDescription(interface.type.short_name,
              true)
          else
            description = interface.name.dup

            # this conditions origin from bridge configuration
            # if including a configured device then its configuration is rewritten
            # to "0.0.0.0/32"
            #
            # translators: a note that listed device is already configured
            description += " " + _("configured") if config.connections.by_name(interface.name)
          end

          selected = included_ifaces.include?(interface.name)
          if physical_port_id?(interface.name)
            description += " (Port ID: #{physical_port_id(interface.name)})"
          end

          result << Yast::Term.new(:item,
            Yast::Term.new(:id, interface.name),
            "#{interface.name} - #{description}",
            selected)
        end
      end

      # With NPAR and SR-IOV capabilities, one device could divide a ethernet
      # port in various. If the driver module support it, we can check the phys
      # port id via sysfs reading the /sys/class/net/$dev_name/phys_port_id
      # TODO: backend method
      #
      # @param dev_name [String] device name to check
      # @return [String] physical port id if supported or a empty string if not
      def physical_port_id(dev_name)
        Yast::SCR.Read(
          Yast::Path.new(".target.string"),
          "/sys/class/net/#{dev_name}/phys_port_id"
        ).to_s.strip
      end

      # @return [boolean] true if the physical port id is not empty
      # TODO: backend method
      # @see #physical_port_id
      def physical_port_id?(dev_name)
        !physical_port_id(dev_name).empty?
      end
    end
  end
end
