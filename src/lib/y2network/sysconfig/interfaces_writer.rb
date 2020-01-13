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
require "y2network/sysconfig/interface_file"
require "y2network/sysconfig/routes_file"

Yast.import "Mode"

module Y2Network
  module Sysconfig
    # This class writes interfaces specific configuration
    #
    # Although it might be confusing, this class is only responsible for writing
    # hardware specific configuration through udev rules.
    #
    # @see Y2Network::InterfacesCollection
    class InterfacesWriter
      include Yast::Logger
      # Writes interfaces hardware configuration and refreshes udev
      #
      # @param interfaces [Y2Network::InterfacesCollection] Interfaces collection
      def write(interfaces)
        shut_down_old_interfaces(interfaces)
        update_udevd(interfaces)
      end

    private

      # Creates an udev rule to rename the given interface
      #
      # @param iface [Interface] Interface to generate the udev rule for
      # @return [UdevRule,nil] udev rule or nil if it is not needed
      def renaming_udev_rule_for(iface)
        log.info("Generating a new udev rule for #{iface.name} based on: " \
                 "#{iface.renaming_mechanism.inspect}")
        case iface.renaming_mechanism
        when :mac
          Y2Network::UdevRule.new_mac_based_rename(iface.name, iface.hardware.mac)
        when :bus_id
          Y2Network::UdevRule.new_bus_id_based_rename(iface.name, iface.hardware.busid,
            iface.hardware.dev_port)
        end
      end

      # Creates an udev rule to set the driver for the given interface
      #
      # @param iface [Interface] Interface to generate the udev rule for
      # @return [UdevRule,nil] udev rule or nil if it is not needed
      def driver_udev_rule_for(iface)
        return nil unless iface.respond_to?(:custom_driver) && iface.custom_driver

        Y2Network::UdevRule.new_driver_assignment(iface.modalias, iface.custom_driver)
      end

      # Renames interfaces and refreshes the udev service
      #
      # @param interfaces [InterfaceCollection] Interfaces
      def update_udevd(interfaces)
        update_renaming_udev_rules(interfaces)
        update_drivers_udev_rules(interfaces)
        reload_udev_rules
      end

      # Updates the given iface udev rule depending on the renaming mechanism
      # selected
      #
      # @param iface [Interface] Interface to update the udev rule for
      # @return [UdevRule] udev rule
      def update_renaming_udev_rule(iface)
        case iface.renaming_mechanism
        when :mac
          iface.udev_rule.rename_by_mac(iface.name, iface.hardware.mac)
        when :bus_id
          iface.udev_rule.rename_by_bus_id(iface.name, iface.hardware.busid,
            iface.hardware.dev_port)
        end

        iface.udev_rule
      end

      # Writes down the current interfaces udev rules and the custom rules that
      # were present when read and that are still valid
      #
      # @see Y2Network::UdevRule#write_net_rules
      def update_renaming_udev_rules(interfaces)
        udev_rules = interfaces.map do |iface|
          update_renaming_udev_rule(iface) if iface.udev_rule
          iface.udev_rule ||= renaming_udev_rule_for(iface)
        end.compact

        known_names = interfaces.known_names
        custom_rules = Y2Network::UdevRule.naming_rules.reject do |u|
          known_names.include?(u.device)
        end
        Y2Network::UdevRule.write_net_rules(custom_rules + udev_rules)
      end

      # @see Y2Network::UdevRule#write_drivers_rules
      def update_drivers_udev_rules(interfaces)
        udev_rules = interfaces.map { |i| driver_udev_rule_for(i) }.compact
        Y2Network::UdevRule.write_drivers_rules(udev_rules)
      end

      def reload_udev_rules
        Yast::Execute.on_target("/usr/bin/udevadm", "control", "--reload")
        Yast::Execute.on_target("/usr/bin/udevadm", "trigger", "--subsystem-match=net",
          "--action=add")
        # wait so that ifcfgs written in NetworkInterfaces are newer
        # (1-second-wise) than netcontrol status files,
        # and rcnetwork reload actually works (bnc#749365)
        Yast::Execute.on_target("/usr/bin/udevadm", "settle")
        sleep(1)
      end

      # Cleans and shutdowns renamed interfaces
      #
      # @param interfaces [InterfacesCollection] Interfaces
      def shut_down_old_interfaces(interfaces)
        interfaces.to_a.select(&:old_name).each { |i| shut_down_interface(i.old_name) }
      end

      # Sets the interface down
      #
      # @param iface_name [String] Interface's name
      def shut_down_interface(iface_name)
        Yast::Execute.on_target("/sbin/ifdown", iface_name) unless Yast::Mode.autoinst
      end
    end
  end
end
