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

require "y2network/interface"
require "y2network/hwinfo"

module Y2Network
  # Physical interface class (ethernet, wireless, infiniband...)
  class PhysicalInterface < Interface
    # @return [String]
    attr_accessor :ethtool_options

    # User selected driver
    #
    # This driver will be set using a udev rule.
    #
    # @return [String]
    attr_accessor :driver

    # Constructor
    #
    # @param name [String] Interface name (e.g., "eth0")
    # @param type [InterfaceType] Interface type
    # @param hardware [Hwinfo] Hardware information
    def initialize(name, type: InterfaceType::ETHERNET, hardware: nil)
      super(name, type: type)
      # @hardware and @name should not change during life of the object
      @hardware = hardware || Hwinfo.for(name) || Hwinfo.new
      @description = @hardware.name
    end

    # Returns interface modalias
    #
    # @return [String,nil] Modalias
    def modalias
      @hardware.modalias
    end

    # Determines whether the interface is present (attached)
    #
    # It relies in the hardware information
    #
    # @return [Boolean]
    # @see Interface#present?
    def present?
      @hardware.present?
    end
  end
end
