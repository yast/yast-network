# encoding: utf-8

# File:        include/network/lan/udev.ycp
# Package:     Network configuration
# Summary:     udev helpers
# Authors:     Michal Filka <mfilka@suse.cz>
#
# Functions for handling udev rules
module Yast
  module NetworkLanUdevInclude
    def GetDefaultUdevRule(dev_name, dev_mac)
      default_rule = [
        "SUBSYSTEM==\"net\"",
        "ACTION==\"add\"",
        "DRIVERS==\"?*\"",
        Builtins.sformat("ATTR{address}==\"%1\"", dev_mac),
        "ATTR{type}==\"1\"",
        Builtins.sformat("NAME=\"%1\"", dev_name)
      ]

      deep_copy(default_rule)
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
