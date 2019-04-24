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
    # FIXME: Direct access to be replaced to make possible
    # Y2Network::Config.interfaces.eth0
    # Y2Network::Config.interfaces.of_type(:eth)
    # ...
    attr_reader :old_items

    extend Forwardable

    def_delegator :@old_items, :each

    # Converts old LanItems::Items into internal data format
    #
    # @return [Interfaces] a container with available interfaces
    def from_lan_items(lan_items)
      # FIXME: should be replaced, separating backend from old API
      @old_items = hash_to_interface(lan_items)
      self
    end

    def find(name)
      @old_items.find { |i| !i.name.nil? ? i.name == name : i.hardware.name }
    end

  private

    # Converts old LanItems::Items into new format
    #
    # @param hash [Hash] a set of interfaces in LanItems::Items format
    # @return [Array<Interface>] a list of interfaces obtained from the hash
    def hash_to_interface(hash)
      hash.map do |_, iface|
        # one of those has to exist in LanItems::Items
        name = iface["ifcfg"] || iface["hwinfo"]["dev_name"]
        Interface.new(name, hwinfo: iface["hwinfo"])
      end
    end
  end
end
