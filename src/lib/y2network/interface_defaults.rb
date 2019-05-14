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
require "yaml"

module Y2Network
  module InterfaceDefaults
    # Initializes device configuration map with default values when needed
    #
    # @param devmap [Hash<String, String>] current device configuration
    #
    # @return device configuration map where unspecified values were set
    #                to reasonable defaults
    def init_device_config(devmap)
      # the defaults here are what sysconfig defaults to
      # (as opposed to what a new interface gets, in {#Select)}
      defaults = YAML.load_file(Yast::Directory.find_data_file("network/sysconfig_defaults.yml"))
      defaults.merge(devmap)
    end

    def init_device_s390_config(devmap)
      Yast.import "Arch"

      return {} if !Yast::Arch.s390

      # Default values used when creating an emulated NIC for physical s390 hardware.
      s390_defaults = YAML.load_file(Directory.find_data_file("network/s390_defaults.yml"))
      s390_defaults.merge(devmap)
    end
  end
end
