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
require "y2network/udev_rule"
require "yast2/execute"

module Y2Network
  module Sysconfig
    # This class writes interfaces specific configuration
    #
    # Although it might be confusing, this class is only responsible for writing
    # hardware specific configuration through udev rules.
    #
    # @see Y2Network::InterfacesCollection
    class InterfacesWriter
      # Writes interfaces hardware configuration and refreshes udev
      #
      # @param interfaces [Y2Network::InterfacesCollection] Interfaces collection
      def write(interfaces)
        udev_rules = interfaces.map { |i| udev_rule_for(i) }.compact
        Y2Network::UdevRule.write(udev_rules)
        update_udevd
      end

    private

      # Creates an udev rule for the given interface
      #
      # @param iface [Interface] Interface to generate the udev rule for
      # @return [UdevRule,nil] udev rule or nil if it is not needed
      def udev_rule_for(iface)
        case iface.renaming_mechanism
        when :mac
          Y2Network::UdevRule.new_mac_based_rename(iface.name, iface.hardware.mac)
        when :bus_id
          Y2Network::UdevRule.new_bus_id_based_rename(iface.name, iface.hardware.busid, iface.hardware.dev_port)
        end
      end

      # Refreshes udev service
      def update_udevd
        Yast::Execute.on_target!("/usr/bin/udevadm", "control", "--reload")
        Yast::Execute.on_target!("/usr/bin/udevadm", "trigger", "--subsystem-match=net", "--action=add")
      end
    end
  end
end
