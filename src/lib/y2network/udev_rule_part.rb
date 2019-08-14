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

module Y2Network
  # Simple class to represent a key-value pair in a udev rule
  #
  # This class does not check whether operators or keys/values are valid or not. We can implement
  # that logic later if required.
  class UdevRulePart
    # Regular expression to match a udev rule part
    PART_REGEXP = Regexp.new("\\A(?<key>[A-Za-z\{\}]+)(?<operator>[^\"]+)\"(?<value>.+)\"\\Z")

    class << self
      # Returns a rule part from a string
      #
      # @example Simple case
      #   part = UdevRulePart.from_string('ACTION=="add"')
      #   part.key #=> "ACTION"
      #   part.operator #=> "=="
      #   part.value #=> "add"
      #
      # @param str [String] string form of an udev rule
      # @return [UdevRule] udev rule object
      def from_string(str)
        match = PART_REGEXP.match(str)
        return if match.nil?
        new(match[:key], match[:operator], match[:value])
      end
    end
    # @return [String] Key name
    attr_accessor :key
    # @return [String] Operator ("==", "!=", "=", "+=", "-=", ":=")
    attr_accessor :operator
    # @return [String] Value to match or assign
    attr_accessor :value

    # Constructor
    #
    # @param key      [String] Key name
    # @param operator [String] Operator ("==", "!=", "=", "+=", "-=", ":=")
    # @param value    [String] Value to match or assign
    def initialize(key, operator, value)
      @key = key
      @operator = operator
      @value = value
    end

    # Determines whether two udev rule parts are equivalent
    #
    # @param other [UdevRulePart] The rule part to compare with
    # @return [Boolean]
    def ==(other)
      key == other.key && operator == other.operator && value == other.value
    end

    alias_method :eql?, :==

    # Returns an string representation of the udev rule part
    #
    # @return [String]
    def to_s
      "#{key}#{operator}\"#{value}\""
    end
  end
end
