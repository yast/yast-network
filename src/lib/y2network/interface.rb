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
    attr_reader :name # TODO: when implementing renaming over new backend modifying name has to be checked
    attr_accessor :renamed_to # TODO: use in renaming workflow
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
      # TODO: move reading hwinfo into Hwinfo class

      # @hardware and @name should not change during life of the object
      @hardware = Hwinfo.new(hwinfo: hwinfo)

      if !(name.nil? || name.empty?)
        @name = name
      else
        # the interface has to be either configured (ifcfg) or known to hwinfo
        raise "Attempting to create representation of nonexistent interface" if hwinfo.nil?
      end

      init(name)
    end

    # Returns interface's current name
    #
    # It means a name which the interface has when all user's changes has been applied
    # (e.g. renaming the interface from eth0 -> enp0s3). This name can differ from the
    # name which the interface had when loaded from system.
    #
    # @see LanItems::current_name_for
    #
    # @return [String] interface name in configuration which is going to be applied to the system
    def current_name
      renamed_to.nil? ? name : renamed_to
    end

    # Determines whether two interfaces are equal
    #
    # @param other [Interface,:any] Interface to compare with
    # @return [Boolean]
    def ==(other)
      return false if other == :any
      name == other.name
    end

    def type
      Yast::NetworkInterfaces.GetType(name)
    end

    def config
      system_config(name)
    end

    # Updates object status according to current system state
    def reload
      init(@name)
    end

    alias_method :eql?, :==

  private

    def system_config(name)
      Yast::NetworkInterfaces.devmap(name)
    end

    # Initializates depending variables
    def init(name)
      @configured = !system_config(name).nil? if !(name.nil? || name.empty?)
    end
  end
end
