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
require "y2network/interface_defaults"

module Y2Network
  # Stores what's needed when creating a new configuration for an interface
  #
  # FIXME: it should be in charge of generating reasonable defaults too
  #        @see LanItems::new_item_default_options & co
  class InterfaceConfigBuilder
    # @return [String] Device name (eth0, wlan0, etc.)
    attr_accessor :name
    # @return [String] type which is intended to be build
    attr_accessor :type

    include Y2Network::InterfaceDefaults

    # Constructor
    #
    # Load with reasonable defaults;
    # see LanItems::new_item_default_options, LanItems::@SysconfigDefaults and
    # others as in LanItems::Select
    def initialize
      # FIXME: following lines updates config with a lot of default options for
      # various device types, we can filter useless options by type when the type
      # gets set or vhen providing configuration back to the user
      @config = init_device_config(new_item_default_options)
      @s390_config = init_device_s390_config({})
    end

    def set(option: nil, value: nil)
      # TODO: guards on option / value
      # TODO: we can validate if the option is reasonable for given type
      # TODO: may be that pushing should be rejected until the type is known
      @config[option] = value
    end

    def option(option)
      @config.fetch(option, "")
    end

    # Provides stored configuration in sysconfig format
    def device_sysconfig
      @config
    end

    # Updates itself according to the given sysconfig configuration
    #
    # @param [Hash<String, String>] a key, value map where key is sysconfig option
    #                               and corresponding value is the option value
    def load_sysconfig(devmap)
      @config = !devmap.nil? ? @config.merge(devmap) : @config
    end

    def load_s390_config(devmap)
      @s390_config = !devmap.nil? ? @s390_config.merge(devmap) : @s390_config
    end
  end
end
