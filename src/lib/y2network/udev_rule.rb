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

require "y2network/udev_rule_part"

module Y2Network
  # Simple udev rule class
  #
  # This class represents a network udev rule. The current implementation is quite simplistic,
  # featuring a an API which is tailored to our needs.
  #
  # Basically, udev rules are kept in two different files under `/etc/udev/rules.d`:
  #
  # * 70-persistent-net.rules ('net' group): rules to assign names to interfaces.
  # * 79-yast2-drivers.rules ('drivers' group): rules to assign drivers to interfaces.
  #
  # This class offers a set of constructors to build different kinds of rules.
  # See {.new_mac_based_rename}, {.new_bus_id_based_rename} and {.new_driver_assignment}.
  #
  # When it comes to write rules to the filesystem, we decided to offer different methods to
  # write to each file. See {.write_net_rules} and {.write_drivers_rules}.
  #
  # @example Create a rule containing some key/value pairs (rule part)
  #   rule = Y2Network::UdevRule.new(
  #     Y2Network::UdevRulePart.new("ATTR{address}", "==", "?*31:78:f2"),
  #     Y2Network::UdevRulePart.new("NAME", "=", "mlx4_ib3")
  #   )
  #   rule.to_s #=> "ACTION==\"add\", SUBSYSTEM==\"net\", ATTR{address}==\"?*31:78:f2\",
  #                  NAME=\"eth0\""
  #
  # @example Create a rule from a string
  #   rule = UdevRule.find_for("eth0")
  #   rule.to_s #=> "ACTION==\"add\", SUBSYSTEM==\"net\", ATTR{address}==\"?*31:78:f2\",
  #                  NAME=\"eth0\""
  #
  # @example Writing renaming rules
  #   rule = UdevRule.new_mac_based_rename("00:12:34:56:78:ab", "eth0")
  #   UdevRule.write_net_rules([rule])
  #
  # @example Writing driver assignment rules
  #   rule = UdevRule.new_driver_assignment("virtio:d00000001v00001AF4", "virtio_net")
  #   UdevRule.write_drivers_rules([rule])
  #
  class UdevRule
    class << self
      # Returns all persistent network rules
      #
      # @return [Array<UdevRule>] Persistent network rules
      def all
        naming_rules + drivers_rules
      end

      # Returns naming rules
      #
      # @return [Array<UdevRule>] Naming network rules
      def naming_rules
        find_rules(:net)
      end

      # Returns driver rules
      #
      # @return [Array<UdevRule>] Drivers rules
      def drivers_rules
        find_rules(:drivers)
      end

      # Returns the udev rule for a given device
      #
      # Only the naming rules are considered.
      #
      # @param device [String] Network device name
      # @return [UdevRule] udev rule
      def find_for(device)
        naming_rules.find { |r| r.device == device }
      end

      # Helper method to create a rename rule based on a MAC address
      #
      # @param name [String] Interface's name
      # @param mac  [String] MAC address
      def new_mac_based_rename(name, mac)
        new_network_rule(
          [
            # Guard to not try to rename everything with the same MAC address (e.g. vlan devices
            # inherit the MAC address from the underlying device).
            # FIXME: it won't work when using predictable network names (openSUSE)
            # UdevRulePart.new("KERNEL", "==", "eth*"),
            # The port number of a NIC where the ports share the same hardware device.
            UdevRulePart.new("ATTR{dev_id}", "==", "0x0"),
            UdevRulePart.new("ATTR{address}", "==", mac),
            UdevRulePart.new("NAME", "=", name)
          ]
        )
      end

      # Helper method to create a rename rule based on the BUS ID
      #
      # @param name     [String] Interface's name
      # @param bus_id   [String] BUS ID (e.g., "0000:08:00.0")
      # @param dev_port [String] Device port
      def new_bus_id_based_rename(name, bus_id, dev_port = nil)
        parts = [UdevRulePart.new("KERNELS", "==", bus_id)]
        parts << UdevRulePart.new("ATTR{dev_port}", "==", dev_port) if dev_port
        parts << UdevRulePart.new("NAME", "=", name)
        new_network_rule(parts)
      end

      # Returns a network rule
      #
      # The network rule includes some parts by default.
      #
      # @param parts [Array<UdevRulePart] Additional rule parts
      # @return [UdevRule] udev rule
      def new_network_rule(parts = [])
        base_parts = [
          UdevRulePart.new("SUBSYSTEM", "==", "net"),
          UdevRulePart.new("ACTION", "==", "add"),
          UdevRulePart.new("DRIVERS", "==", "?*"),
          # Ethernet devices
          # https://github.com/torvalds/linux/blob/bb7ba8069de933d69cb45dd0a5806b61033796a3/include/uapi/linux/if_arp.h#L31
          # TODO: what about InfiniBand (it is type 32)?
          UdevRulePart.new("ATTR{type}", "==", "1")
        ]
        new(base_parts.concat(parts))
      end

      # Returns a module assignment rule
      #
      # @param modalias    [String] Interface's modalias
      # @param driver_name [String] Module name
      # @return [UdevRule] udev rule
      def new_driver_assignment(modalias, driver_name)
        parts = [
          UdevRulePart.new("ENV{MODALIAS}", "==", modalias),
          UdevRulePart.new("ENV{MODALIAS}", "=", driver_name)
        ]
        new(parts)
      end

      # Writes udev rules to the filesystem
      #
      # @param udev_rules [Array<UdevRule>] List of udev rules
      def write_net_rules(udev_rules)
        Yast::SCR.Write(Yast::Path.new(".udev_persistent.rules"), udev_rules.map(&:to_s))
        # Writes changes to the rules file
        Yast::SCR.Write(Yast::Path.new(".udev_persistent.nil"), [])
      end

      # Writes drivers specific udev rules to the filesystem
      #
      # Those rules that does not have an MODALIAS part will be ignored.
      #
      # @param udev_rules [Array<UdevRule>] List of udev rules
      def write_drivers_rules(udev_rules)
        rules_hash = udev_rules.each_with_object({}) do |rule, hash|
          driver = rule.part_value_for("ENV{MODALIAS}", "=")
          next unless driver

          hash[driver] = rule.parts.map(&:to_s)
        end
        Yast::SCR.Write(Yast::Path.new(".udev_persistent.drivers"), rules_hash)
        # Writes changes to the rules file
        Yast::SCR.Write(Yast::Path.new(".udev_persistent.nil"), [])
      end

      # Clears rules cache map
      def reset_cache
        @all = nil
      end

    private

      def find_rules(group)
        @all ||= {}
        return @all[group] if @all[group]

        rules_map = Yast::SCR.Read(Yast::Path.new(".udev_persistent.#{group}")) || {}
        @all[group] = rules_map.values.map do |parts|
          udev_parts = parts.map { |p| UdevRulePart.from_string(p) }.compact
          new(udev_parts)
        end
      end
    end

    # @return [Array<UdevRulePart>] Parts of the udev rule
    attr_reader :parts

    # Constructor
    #
    # @param parts [Array<UdevRulePart>] udev rule parts
    def initialize(parts = [])
      @parts = parts
    end

    # Adds a part to the rule
    #
    # @param key      [String] Key name
    # @param operator [String] Operator
    # @param value    [String] Value to match or assign
    def add_part(key, operator, value)
      @parts << UdevRulePart.new(key, operator, value)
    end

    # Returns an string representation that can be used in a rules file
    #
    # @return [String]
    def to_s
      parts.map(&:to_s).join(", ")
    end

    # Returns the part with the given key
    #
    # @param key [String] Key name to match
    # @param operator [String,nil] Operator to match; nil omits matching the operator
    def part_by_key(key, operator = nil)
      parts.find { |p| p.key == key && (operator.nil? || p.operator == operator) }
    end

    # Returns the value for a given part
    #
    # @param key [String] Key name
    # @param operator [String,nil] Operator to match; nil omits matching the operator
    # @return [String,nil] Value or nil if not found a part which such a key
    def part_value_for(key, operator = nil)
      part = part_by_key(key, operator)
      return nil unless part

      part.value
    end

    # Returns the MAC in the udev rule
    #
    # @return [String,nil] MAC address or nil if not found
    # @see #part_value_for
    def mac
      part_value_for("ATTR{address}")
    end

    # Convenience method to replace a specific part by another one. In case
    # that there is no part to be replaced then a new part is added.
    #
    # @param key      [String] Key name
    # @param operator [String] Operator
    # @param value    [String] Value to match or assign
    # @see #add_part
    def replace_part(key, operator, value)
      part = part_by_key(key, operator)
      if part
        part.value = value
      else
        add_part(key, operator, value)
      end
    end

    # Convenience method which takes care of modifing the udev rule using the
    # MAC address as the naming mechanism
    def rename_by_mac(name, address)
      parts.delete_if(&:dev_port?)
      part = part_by_key("KERNELS")
      part.key = "ATTR{address}" if part

      replace_part("ATTR{address}", "==", address) if mac != address
      ## Ensure the name is always at the end of the rule
      parts.delete_if { |p| p.dev_port? || p.name? }
      add_part("NAME", "=", name)
    end

    # Convenience method which takes care of modifing the udev rule using the
    # bus_id and the dev_port when needed as the naming mechanism
    def rename_by_bus_id(name, bus_id_value, dev_port_value = nil)
      parts.delete_if { |p| (p.dev_port? && dev_port_value.nil?) }
      part = part_by_key("ATTR{address}")
      part.key = "KERNELS" if part

      replace_part("KERNELS", "==", bus_id_value) if bus_id != bus_id_value
      replace_part("ATTR{dev_port}", "==", dev_port_value) if dev_port != dev_port_value
      ## Ensure the name is always at the end of the rule
      parts.delete_if(&:name?)
      add_part("NAME", "=", name)
    end

    # Returns the BUS ID in the udev rule
    #
    # @return [String,nil] BUS ID or nil if not found
    # @see #part_value_for
    def bus_id
      part_value_for("KERNELS")
    end

    # Returns the device port in the udev rule
    #
    # @return [String,nil] Device port or nil if not found
    # @see #part_value_for
    def dev_port
      part_value_for("ATTR{dev_port}")
    end

    # Returns the device mentioned in the rule (if any)
    #
    # @return [String,nil] Device name or nil if not found
    def device
      part_value_for("NAME", "=")
    end

    # Returns the original modalias
    #
    # @return [String,nil] Original modalias or nil if not found
    def original_modalias
      part_value_for("ENV{MODALIAS}", "==")
    end

    # Returns the modalias
    #
    # @return [String,nil] Original modalias or nil if not found
    def driver
      part_value_for("ENV{MODALIAS}", "=")
    end
  end
end
