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

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class VlanID < CWM::IntField
      # Constructor
      #
      # @param config [Y2Network::InterfaceConfigBuilder] Interface configuration builder object
      def initialize(config)
        super()
        textdomain "network"

        @config = config
      end

      def label
        _("VLAN ID")
      end

      def help
        # TODO: previously not exist, so write it
        ""
      end

      def init
        self.value = @config.vlan_id
      end

      def store
        return unless modified?

        @config.rename_interface(suggested_name) if suggest_vlan_name
        @config.vlan_id = value
      end

      def minimum
        0
      end

      def maximum
        9999
      end

    private

      def modified?
        @config.vlan_id != value
      end

      def suggested_name
        "vlan#{value}"
      end

      def suggest_vlan_name
        # If the interface name is modified before the VLAN ID, we should not
        # suggest any change
        return false if @config.name == suggested_name

        Yast::Popup.YesNo(
          format(
            # TRANSLATORS: Suggest the user to modify the interface name
            # %{vlanid} is the modified VLAN ID, %{name} is the current
            # interface name and %{sname} is the interface name
            # proposed based on the new VLAN ID
            _("VLAN with ID '%{vlanid}' has been defined.\n\n" \
              "Would you like to adapt the interface name from '%{name}' to '%{sname}'?"),
            vlanid: value, name: @config.name, sname: suggested_name
          )
        )
      end
    end
  end
end
