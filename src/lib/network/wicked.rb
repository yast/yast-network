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
require "shellwords"

module Yast
  module Wicked
    BASH_PATH = Path.new(".target.bash")
    BASH_OUTPUT_PATH = Path.new(".target.bash_output")

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
      raise ArgumentError, "A network device has to be specified" if iface.nil? || iface.empty?
      if !NetworkService.is_wicked
        raise "Parsing NTP Servers not supported for network service in use"
      end

      lease_files = ["ipv4", "ipv6"].map { |ip| "/var/lib/wicked/lease-#{iface}-dhcp-#{ip}.xml" }
      lease_files.find_all { |f| File.file?(f) }.reduce([]) do |stack, file|
        result = SCR.Execute(BASH_OUTPUT_PATH,
          "/usr/sbin/wicked xpath --file #{file.shellescape} \"%{//ntp/server}\"")

        stack + result.fetch("stdout", "").split("\n")
      end
    end
  end
end
