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
require "pathname"
require "ipaddr"

module Y2Network
  # This class represents a sysconfig file containing an interface configuration
  #
  # @example Finding the file for a given interface
  #   file = Y2Network::SysconfigInterfaceFile.find("wlan0")
  #   file.fetch("WIRELESS_ESSID") #=> "dummy"
  class SysconfigInterfaceFile
    # @return [String] Interface name
    class << self
      SYSCONFIG_NETWORK_DIR = Pathname.new("/etc/sysconfig/network").freeze

      # Finds the ifcfg-* file for a given interface
      #
      # @param name [String] Interface name
      # @return [SysconfigInterfaceFile,nil] Sysconfig
      def find(name)
        return nil unless Yast::FileUtils.Exists(SYSCONFIG_NETWORK_DIR.join("ifcfg-#{name}").to_s)
        new(name)
      end
    end

    attr_reader :name

    # Constructor
    #
    # @param name [String] Interface name
    def initialize(name)
      @name = name
    end

    # Returns the IP address if defined
    #
    # @return [IPAddr,nil] IP address or nil if it is not defined
    def ip_address
      str = fetch("IPADDR")
      str.empty? ? nil : IPAddr.new(str)
    end

    # Fetches a key
    #
    # @param key [String] Interface key
    # @return [Object] Value for the given key
    def fetch(key)
      path = Yast::Path.new(".network.value.\"#{name}\".#{key}")
      Yast::SCR.Read(path)
    end
  end
end
