# Copyright (c) [2020] SUSE LLC
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
require "cwm/table"

module Y2Network
  module Widgets
    # This class
    class WirelessNetworks < CWM::Table
      attr_reader :selected

      # Constructor
      #
      # @param networks [Array<WirelessNetwork>] List of available wifi networks
      # @param builder [InterfaceConfigBuilder]
      def initialize(builder, networks = [])
        textdomain "network"
        @networks = networks
        @builder = builder
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @builder.essid if @builder.essid
        # FIXME: the dialog does not implement this method, so we need to set the focus
        # within the widget. We should find a better way.
        focus
      end

      # Returns table headers
      #
      # @return [Array<String>]
      def header
        [_("ESSID"), _("Mode"), _("Channel"), _("Rate"), _("Signal"), _("Authentication")]
      end

      # Returns table items
      #
      # Each item corresponds to a wireless network.
      #
      # @return [Array<Array<String>>]
      def items
        @networks.map do |network|
          [
            network.essid,
            network.essid,
            network.mode,
            network.channel,
            network.rates.max.to_s,
            network.quality ? "#{network.quality}%" : "",
            network.auth_mode&.to_human_string
          ]
        end
      end

      # Updates the list of networks
      #
      # @param networks [Array<WirelessNetwork>] List of wireless networks
      def update(networks)
        @networks = networks
        old_value = Yast::UI.QueryWidget(Id(widget_id), :SelectedItems)
        change_items(items)
        self.value = old_value if old_value
      end

      # @see CWM::AbstractWidget
      def store
        @selected = @networks.find { |n| n.essid == value }
      end
    end
  end
end
