# Copyright (c) [2021] SUSE LLC
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
  # Represents a bitrate
  #
  # This class is not as generic as Y2Storage::DiskSize and it is used to support
  # parsing bitrates information from `iwlist`. However, it could be extended
  # in the future if needed.
  class Bitrate
    include Comparable

    # Exception when trying to parse a string as a bitrate
    class ParseError < StandardError; end

    PARSE_REGEXP = /\A(\d+(?:.\d+)?)\ *(\w+)?/.freeze
    private_constant :PARSE_REGEXP

    UNITS = ["b", "kb", "Mb", "Gb"].freeze
    private_constant :UNITS


    class << self
      # Parses a string and converts the value to a string
      #
      # @example Parsing Mb/s
      #   bitrate = Bitrate.parse("54 Mb/s")
      #   bitrate.to_i #=> 54000000
      #   bitrate.to_s #=> "54 Mb/s"
      #
      # @param str [String] String to parse
      # @return [Bitrate]
      # @raise ParseError
      def parse(str)
        match = PARSE_REGEXP.match(str)
        raise ParseError unless match

        number, unit = match.captures
        unit ||= "b"
        power = UNITS.index(unit)
        raise ParseError unless power

        new(number.to_i * (1000**power))
      end
    end

    # @param bits [Integer] Bits
    def initialize(bits)
      @bits = bits
    end

    # @return [Integer] Return the bits
    def to_i
      @bits
    end

    # Returns the string representation of the bitrate
    #
    # It automatically selects the unit to use depending on the bitrate value.
    #
    # @return [String] String representation
    def to_s
      power = (0..UNITS.length - 1).to_a.reverse.find do |u|
        to_i > (1000**u)
      end

      units = UNITS[power]
      number = @bits.to_f / (1000**power)
      number_str = number.to_s.sub(".0", "") # strip insignificant zeroes

      "#{number_str} #{units}/s"
    end

    # Compare two bitrates
    #
    # @param other [Bitrate]
    # @return [Integer]
    def <=>(other)
      to_i <=> other.to_i
    end
  end
end
