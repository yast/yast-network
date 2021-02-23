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
# encoding: utf-8

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

require "yast"
require "yast2/execute"
require "y2network/bitrate"
require "y2network/wireless_network"
require "y2network/wireless_cell"

module Y2Network
  # Scans for wireless cells (access points and ad-hoc cells)
  #
  # It uses the `iwlist` command line utility to get the cells information.
  #
  # @example Getting cells through the an interfaced named "wlo1"
  #   scanner = WirelessScanner.new("wlo1")
  #   scanner.cells #=> [#<Y2Network::WirelessNetwork...>]
  class WirelessScanner
    include Yast::Logger

    # @return [String] Name of the interface to scan for devices
    attr_reader :iface_name

    # Constructor
    #
    # @param iface_name [String] Name of the interface that will be used to scan for devices
    def initialize(iface_name)
      @iface_name = iface_name
    end

    # Returns the wireless cells
    #
    #
    # @return [Array<WirelessNetwork>] List of wireless cells
    def cells
      raw_cells_from_iwlist(fetch_iwlist).map do |cell|
        cell_from_raw_data(cell)
      end
    rescue Cheetah::ExecutionFailed => e
      log.error "Could not fetch the list of wireless cells: #{e.inspect}"
      []
    end

  private

    # Fetches iwlist command output
    #
    # @return [String]
    # @raise Cheetah::ExecutionFailed
    def fetch_iwlist
      Yast::Execute.locally(["/usr/sbin/ip", "link", "set", iface_name, "up"])
      Yast::Execute.locally!(
        ["/usr/sbin/iwlist", iface_name, "scan"], stdout: :capture
      )
    end

    # Returns an array containing the iwlist output for each cell
    #
    # @param iwlist [String] "iwlist" output
    # @return [Array<String>] Array containing iwlist output for each cell
    def raw_cells_from_iwlist(iwlist)
      cell_sections = iwlist.split(/Cell \d+ -/)
      return [] unless cell_sections.size > 1

      cell_sections[1..-1].map do |cell|
        cell.gsub(/\ {20}/, "")
      end
    end

    # Converts a cell section from iwlist into a proper cell object
    #
    # @param raw_cell [String] iwlist string describing a cell
    # @return [Cell] Cell representation
    def cell_from_raw_data(raw_cell)
      fields = cell_fields(raw_cell)
      WirelessCell.new(
        address:  fetch_address(fields),
        essid:    fetch_essid(fields),
        mode:     field_single_value("Mode", fields),
        channel:  fetch_channel(fields),
        rates:    fetch_bit_rates(fields),
        quality:  fetch_quality(fields),
        security: fetch_security(fields)
      )
    end

    # Turns a iwlist cell section into an array of hashes where each element represents a field
    #
    # @example Example output containing keys with multiple values
    #   [
    #     { key: "ESSID", value: "MY_WIFI" }, { key: "Bit Rates", value: ["12 Mb/s", "54 Mb/s"] },
    #     { key: "Bit Rates", value: ["2 Mb/s"] }
    #   ]
    #
    # @return [Array<Hash>] Array containing names and values for each field. Each hash represents
    #   a field using a `key` and `value` attributes.
    def cell_fields(cell)
      key = cell[/\A[^:=]+/]
      end_pos = cell.index(/\n[^ ]/) || cell.size
      value = cell[(key.size + 1)..end_pos - 1]
      remaining = cell[(end_pos + 1)..-1]

      current = { key: key.strip, value: value&.strip }
      return [current] if remaining.nil?

      [current] + cell_fields(remaining)
    end

    # Returns all the values of the given field
    #
    # @param key [String] Field name
    # @return [Array<String>] Values of the given field
    def field_multi_values(key, fields)
      fields
        .select { |f| f[:key] == key }
        .map { |f| f[:value] }
    end

    # Returns the first value of the given field
    #
    # This method is useful for those fields that are expected to have just a single value.
    #
    # @param key [String] Field name
    # @return [String] Values of the given field
    def field_single_value(key, fields)
      field_multi_values(key, fields).first
    end

    # Returns the cell MAC address from the list of fields
    #
    # @param fields [Array<Hash>] Cell fields
    # @return [String,nil] Returns the MAC address or nil if it was not found
    def fetch_address(fields)
      field_single_value("Address", fields)
    end

    # Returns the ESSID from the list of fields
    #
    # @param fields [Array<Hash>] Cell fields
    # @return [String,nil] Returns the ESSID or nil if it was not found
    def fetch_essid(fields)
      value = field_single_value("ESSID", fields)
      return nil if value.nil?

      value[/"(.+)"/, 1]
    end

    # Returns the bit rates from the list of fields
    #
    # @param fields [Array<Hash>] Cell fields
    # @return [Array<String>] Returns bit rates
    def fetch_bit_rates(fields)
      field_multi_values("Bit Rates", fields)
        .join("\n")
        .gsub("\n", ";")
        .split(";")
        .map { |b| Bitrate.parse(b.strip) }
    end

    # Returns the quality from the list of fields
    #
    # @param fields [Array<Hash>] Cell fields
    # @return [Integer,nil] Returns the quality or nil if it was not found
    def fetch_quality(fields)
      value = field_single_value("Quality", fields)
      return nil if value.nil?

      value[/(\d+)\/.+/, 1]&.to_i
    end

    # Returns the channel from the list of fields
    #
    # @param fields [Array<Hash>] Cell fields
    # @return [Integer,nil] Returns the channel or nil if it was not found
    def fetch_channel(fields)
      field_single_value("Channel", fields)&.to_i
    end

    # Returns the channel from the list of fields
    #
    # @param fields [Array<Hash>] Cell fields
    # @return [Symbol] Authentication mode (:open, :shared, :psk or :eap)
    def fetch_security(fields)
      values = field_multi_values("IE", fields)
        .reject { |i| i.start_with?("Unknown:") }
      auth_modes = values.map { |v| v.split("\n").first }

      return :psk if auth_modes.any? { |a| a.include?("WPA") }

      return :shared if field_single_value("Encryption key", fields) == "on"

      :open
    end
  end
end
