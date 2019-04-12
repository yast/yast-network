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
require "y2network/interfaces/physical"
require "y2network/interfaces/virtual"
require "forwardable"

module Y2Network
  # A container for network devices. In the end should carry methods for mass operations
  # over network interfaces like old LanItems::find_dhcp_ifaces or so.
  #
  # FIXME: Intended for LanItems::Items separation
  # proper cleanup is must
  class Interfaces
    attr_reader :old_items

    extend Forwardable

    def_delegator :@old_items, :each

    def initialize(old_items:)
      # FIXME: should be replaced, separating backend from old API
      @old_items = hash_to_interface(old_items)
    end

  private

    # Converts old LanItems::Items into new format
    def hash_to_interface(hash)
      hash.map do |_, iface|
        Interface.new(iface["ifcfg"], hwinfo: iface["hwinfo"])
      end
    end
  end
end
