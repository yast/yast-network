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

require "forwardable"
require "y2network/hwinfo"

Yast.import "NetworkInterfaces"

module Y2Network
  # Network interface.
  class Interface
    # @return [String] Device name (eth0, wlan0, etc.)
    attr_accessor :name # TODO: when implementing renaming over new backend modifying name has to be checked
    attr_reader :configured
    attr_reader :hardware

    extend Forwardable

    def_delegator :@hardware, :exists?, :hardware?

    # Shortcuts for accessing interfaces' ifcfg options
    ["STARTMODE"].each do |ifcfg_option|
      define_method ifcfg_option.downcase do
        # when switching to new backend we need as much guards as possible
        if !configured || self.config.nil? || self.config.empty?
          raise "Trying to read configuration of unconfigured interface"
        end

        self.config[ifcfg_option]
      end
    end

    # Constructor
    #
    # @param name [String] Interface name (e.g., "eth0")
    def initialize(name, hwinfo: nil)
      @hardware = Hwinfo.new(hwinfo: hwinfo)
      @name = name
      # FIXME: definitely has to be fixed for not configured devices
      @configured = !(name.nil? || name.empty?)
    end

    # Determines whether two interfaces are equal
    #
    # @param other [Interface] Interface to compare with
    # @return [Boolean]
    def ==(other)
      return false unless other.is_a?(Interface)
      name == other.name
    end

    def type
      Yast::NetworkInterfaces.GetType(name)
    end

    def config
      Yast::NetworkInterfaces.devmap(name)
    end

    # eql? (hash key equality) should alias ==, see also
    # https://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==
  end
end
