# encoding: utf-8

# File:        include/network/lan/udev.ycp
# Package:     Network configuration
# Summary:     udev helpers
# Authors:     Michal Filka <mfilka@suse.cz>
#
# Functions for handling udev rules
module Yast
  module NetworkLanUdevInclude

    # Creates default udev rule for given NIC.
    #
    # Udev rule is based on device's MAC.
    #
    # @return [Array] an udev rule
    def GetDefaultUdevRule(dev_name, dev_mac)
      default_rule = [
        "SUBSYSTEM==\"net\"",
        "ACTION==\"add\"",
        "DRIVERS==\"?*\"",
        "ATTR{address}==\"#{dev_mac}\"",
        "ATTR{type}==\"1\"",
        "NAME=\"#{dev_name}\""
      ]
    end

    def update_udev_rule_key(rule, key, value)
      return rule if rule.nil? || rule.empty?

      raise ArgumentError if key.nil?
      raise ArgumentError if value.nil?

      i = rule.find_index { |k| k =~ /^#{key}/ }

      if i
        rule[i] = rule[i].gsub(/#{key}={1,2}"([^"]*)"/) do |m|
          m.gsub($1, value)
        end
      end

      rule
    end

    # Removes (key,operator,value) tripplet from given udev rule.
    def RemoveKeyFromUdevRule(rule, key)
      rule = deep_copy(rule)
      pattern = Builtins.sformat("%1={1,2}[^[:space:]]*", key)

      Builtins.filter(rule) { |atom| !Builtins.regexpmatch(atom, pattern) }
    end

    # Adds (key, operator, value) tripplet into given udev rule
    #
    # Tripplet is given as a string in form KEY="VALUE" or
    # MATCHKEY=="MATCHVALUE"
    def AddToUdevRule(rule, tripplet)
      rule = deep_copy(rule)
      if !Builtins.regexpmatch(tripplet, ".+={1,2}\".*\"")
        return deep_copy(rule)
      end
      rule = [] if rule == nil

      Builtins.add(rule, tripplet)
    end
  end
end
