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

module Y2Network
  # Stores what's needed when creating a new configuratoon for an interface
  class InterfaceConfigBuilder
    # @return [String] Device name (eth0, wlan0, etc.)
    attr_accessor :name
    # @return [String] type which is intended to be build
    attr_accessor :type

    # Constructor
    def initialize
      # FIXME: load with reasonable defaults;
      # see LanItems::new_item_default_options, LanItems::@SysconfigDefaults and
      # others as in LanItems::Select
      @config = {}
    end

    def push(option: option, value: value)
      # TODO: we can validate if the option is reasonable for given type
      # TODO: may be that pushing should be rejected until the type is known
      @config.store(option, value)
    end
end
