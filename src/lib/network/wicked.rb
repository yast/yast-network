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
require "yast2/execute"
require "shellwords"

module Yast
  module Wicked
    BASH_PATH = Path.new(".target.bash")
    BASH_OUTPUT_PATH = Path.new(".target.bash_output")
    IBFT_CMD = "/etc/wicked/extensions/ibft".freeze
    WICKED_PATH = "/usr/sbin/wicked".freeze

    # Reloads configuration for each device named in devs
    #
    # @param devs [Array] list of device names
    # @return [Boolean] true if configuration was reloaded; false otherwise
    def reload_config(devs)
      raise ArgumentError if devs.nil?
      return true if devs.empty?

      SCR.Execute(BASH_PATH, "/usr/sbin/wicked ifreload #{devs.map(&:shellescape).join(" ")}").zero?
    end

    # Parses wicked runtime configuration and returns list of ntp servers
    #
    # @param iface [String] network device
    # @return [Array<String>] list of NTP servers
    def parse_ntp_servers(iface)
      query_wicked(iface, "//ntp/server")
    end

    # Parses wicked runtime configuration and returns hostname if set
    #
    # @param iface [String] network device
    # @return [String] hostname
    def parse_hostname(iface)
      result = query_wicked(iface, "//hostname")
      # If there is more than one just pick the first one
      result.first
    end

    # Parses wicked runtime dhcp lease file for the given query
    #
    # It parses both ipv4 and ipv6 lease files at once.
    #
    # @param iface [String] queried interface
    # @param query [String] xpath query. See man wicked for info what is supported there.
    # @return [String] result of the query
    def query_wicked(iface, query)
      Yast.import "NetworkService"
      raise ArgumentError, "A network device has to be specified" if iface.nil? || iface.empty?
      raise "Parsing not supported for network service in use" if !NetworkService.is_wicked

      lease_files = ["ipv4", "ipv6"].map { |ip| "/var/lib/wicked/lease-#{iface}-dhcp-#{ip}.xml" }
      lease_files.find_all { |f| File.file?(f) }.reduce([]) do |stack, file|
        result = SCR.Execute(
          BASH_OUTPUT_PATH,
          "/usr/sbin/wicked xpath --file #{file.shellescape} \"%{#{query}}\""
        )

        stack + result.fetch("stdout", "").split("\n")
      end
    end

    # Returns an array of interface names which are configured using iBFT
    #
    # @return [Array <String>] array of interface names
    def ibft_interfaces
      Yast::Execute.stdout.locally!(IBFT_CMD, "-l").split(/\s+/).uniq
    end

    # Returns an array of interface names which are configured via firmware
    #
    # @return [Array <String>] array of interface names
    def firmware_interfaces
      interfaces = firmware_interfaces_by_extension.values.flatten
      (ibft_interfaces + interfaces).uniq
    end

    # Returns a hash with each firmware extension as the key and the specific extension
    # configured interfaces as the value
    #
    # @return [Hash] configured by firmware interfaces indexed by the firmware extension
    def firmware_interfaces_by_extension
      output = Yast::Execute.stdout.locally!(WICKED_PATH, "firmware", "interfaces")
      output.split("\n").each_with_object({}) do |line, result|
        firmware, *interfaces = line.split(/\s+/)
        result[firmware] = result.fetch(firmware, []) + interfaces if firmware
      end
    end

    # Returns the firmware extension used for configuring the given interface or nil when it is not
    # configured by firmware
    #
    # @return [String, nil] Firmware extension used for configuring the interface or nil
    def firmware_configured_by?(interface)
      firmware_interfaces_by_extension.find { |_, v| v.include?(interface) }&.first
    end
  end
end
