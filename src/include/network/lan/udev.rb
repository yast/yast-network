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

module Yast
  # Functions for handling udev rules
  module NetworkLanUdevInclude
    # Creates default udev rule for given NIC.
    #
    # Udev rule is based on device's MAC.
    #
    # @return [Array] an udev rule
    def GetDefaultUdevRule(dev_name, dev_mac)
      [
        "SUBSYSTEM==\"net\"",
        "ACTION==\"add\"",
        "DRIVERS==\"?*\"",
        "ATTR{address}==\"#{dev_mac}\"",
        "ATTR{type}==\"1\"",
        "NAME=\"#{dev_name}\""
      ]
    end

    # Updates existing key in a rule to new value.
    # Modifies rule and returns it.
    # If key is not found, rule is unchanged.
    def update_udev_rule_key(rule, key, value)
      return rule if rule.nil? || rule.empty?

      raise ArgumentError if key.nil?
      raise ArgumentError if value.nil?

      i = rule.find_index { |k| k =~ /^#{key}/ }

      if i
        rule[i] = rule[i].gsub(/#{key}={1,2}"([^"]*)"/) do |m|
          m.gsub(Regexp.last_match(1), value)
        end
      end

      rule
    end

    # Returns a value of the particular key in the rule
    #
    # @param rule [array] an udev rule represented as a list of strings
    # @param key  [string] a key name which is asked for value
    # @return     [string] value corresponding to the key or empty string
    def udev_key_value(rule, key)
      raise ArgumentError, "Rule must not be nil when querying a key value" if rule.nil?

      rule.each do |tuple|
        # note that when using =~ then named capture groups (?<name>...) currently
        # cannot be used together with interpolation (#{})
        # see http://stackoverflow.com/questions/15890729/why-does-capturing-named-groups-in-ruby-result-in-undefined-local-variable-or-m
        matches = tuple.match(/#{key}={1,2}"?(?<value>[^[:space:]"]*)/)
        return matches[:value] if matches
      end

      ""
    end

    # Writes new persistent udev net rules and tells udevd to update its configuration
    def write_update_udevd(udev_rules)
      SCR.Write(path(".udev_persistent.rules"), udev_rules)
      SCR.Write(path(".udev_persistent.nil"), [])

      update_udevd
    end

    # Tells udevd to reload and update its configuration
    #
    # @return [boolean] false when new configuration cannot be activated
    def update_udevd
      SCR.Execute(path(".target.bash"), "/usr/bin/udevadm control --reload")

      # When configuring a new s390 card, we neglect to fill
      # its Items[i, "udev", "net"], causing jumbled names (bnc#721520)
      # The udev trigger will make udev write the persistent names
      # (which it already has done, but we have overwritten them now).
      ret = SCR.Execute(
        path(".target.bash"),
        "/usr/bin/udevadm trigger --subsystem-match=net --action=add"
      )
      ret.zero?
    end

    # Removes (key,operator,value) tripplet from given udev rule.
    def RemoveKeyFromUdevRule(rule, key)
      pattern = /#{key}={1,2}\S*/

      rule.delete_if { |tripplet| tripplet =~ pattern }
    end

    # Adds (key, operator, value) tripplet into given udev rule
    #
    # Tripplet is given as a string in form KEY="VALUE" or
    # MATCHKEY=="MATCHVALUE"
    def AddToUdevRule(rule, tripplet)
      return rule unless tripplet =~ /.+={1,2}\".*\"/

      rule ||= []
      rule + [tripplet]
    end
  end
end
