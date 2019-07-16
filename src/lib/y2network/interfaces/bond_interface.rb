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

require "y2network/interfaces/virtual_interface"

module Y2Network
  module Interfaces
    class BondInterface < VirtualInterface

      # Returns list of interfaces enslaved in the bond interface
      #
      # @return [Y2Network::InterfacesCollection] interfaces enslaved in the bond
      # TODO: reading from backend should be handled elsewhere
      def slaves
        @slaves ||= bond_slaves(name).map do |iface|
          type = Yast::NetworkInterfaces.GetType(iface)
          Y2Network::Interface.for(iface, InterfaceType.from_short_name(type))
        end

        Y2Network::InterfacesCollection.new(@slaves)
      end

    private
      # Creates list of devices enslaved in the bond device.
      #
      # @param bond_iface [String] a name of an interface of bond type
      # @return list of names of interfaces enslaved in the bond_iface
      def bond_slaves(bond_iface)
        bond_map = Yast::NetworkInterfaces::FilterDevices("netcard").fetch("bond", {}).fetch(bond_iface, {})

        bond_map.select { |k, _| k.start_with?("BONDING_SLAVE") }.values
      end
    end
  end
end
