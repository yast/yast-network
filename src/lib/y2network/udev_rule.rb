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
  # featuring a pretty simple API.
  #
  # @example Create a rule containing some key/value pairs (rule part)
  #   rule = Y2Network::UdevRule.new(
  #     Y2Network::UdevRulePart.new("ATTR{address}", "==", "?*31:78:f2"),
  #     Y2Network::UdevRulePart.new("NAME", "=", "mlx4_ib3")
  #   )
  #   rule.to_s #=> "ACTION==\"add\", SUBSYSTEM==\"net\", ATTR{address}==\"?*31:78:f2\", NAME=\"eth0\""
  #
  # @example Create a rule from a string
  #   rule = UdevRule.find_for("eth0")
  #   rule.to_s #=> "ACTION==\"add\", SUBSYSTEM==\"net\", ATTR{address}==\"?*31:78:f2\", NAME=\"eth0\""
  class UdevRule
    class << self
      # Returns all persistent network rules
      #
      # @return [Array<UdevRule>] Persistent network rules
      def all
        return @all if @all
        rules_map = Yast::SCR.Read(Yast::Path.new(".udev_persistent.net")) || {}
        @all = rules_map.values.map do |parts|
          udev_parts = parts.map { |p| UdevRulePart.from_string(p) }
          new(udev_parts)
        end
      end

      # Returns the udev rule for a given device
      #
      # @param device [String] Network device name
      # @return [UdevRule] udev rule
      def find_for(device)
        all.find { |r| r.device == device }
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

      # Writes udev rules to the filesystem
      #
      # @param udev_rules [Array<UdevRule>] List of udev rules
      def write(udev_rules)
        Yast::SCR.Write(Yast::Path.new(".udev_persistent.rules"), udev_rules.map(&:to_s))
        Yast::SCR.Write(Yast::Path.new(".udev_persistent.nil"), []) # Writes changes to the rules file
      end

      # Clears rules cache map
      def reset_cache
        @all = nil
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
    def device
      part_value_for("NAME", "=")
    end
  end
end
