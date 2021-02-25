# Copyright (c) [2021] SUSE LLC
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

require "yast2/feedback"
require "y2network/widgets/wireless_networks"
require "y2network/wireless_network"
require "cwm/popup"

Yast.import "Label"

module Y2Network
  module Dialogs
    # Button that runs an custom action when it is clicked
    class CallbackButton < ::CWM::PushButton
      # @param label [String] Button label
      # @param block [Proc] Action to run
      def initialize(label, &block)
        @label = label
        @block = block
      end

      # @see CWM::AbstractWidget
      def label
        @label
      end

      # @see CWM::CustomWidget
      def handle
        @block.call

        nil
      end
    end

    # This widget displays a list of wireless networks and allows the user to select one
    #
    # @example Returning the ESSID of the selected network
    #   WirelessNetworks.new("wlo1").run #=> "sample_essid"
    class WirelessNetworks < CWM::Popup
      attr_reader :interface

      # Constructor
      def initialize(interface)
        textdomain "network"
        @interface = interface
      end

      # @see CWM::AbstractWidget
      def title
        _("Available Wireless Networks")
      end

      # @see CWM::CustomWidget
      def contents
        VBox(
          MinSize(70, 10, networks_table),
          refresh_button
        )
      end

      # Runs the dialog and returns the selected network instance
      #
      # If the user presses the 'Cancel' button, it returns `nil`.
      #
      # @return [WirelessNetwork] Network or `nil` if the dialog was canceled
      def run
        networks_table.update(find_networks)
        (super == :ok) ? networks_table.selected : nil
      end

    private

      # Returns the label for the 'Accept' button
      #
      # @return [String]
      def ok_button_label
        Yast::Label.SelectButton
      end

      # Refresh button
      #
      # @return [Yast::Term]
      def refresh_button
        CallbackButton.new(_("Refresh")) { networks_table.update(find_networks) }
      end

      # Embedded wireless networks table
      #
      # @return [Y2Network::Widgets::WirelessNetworks] Wireless networks table widget
      def networks_table
        @networks_table ||= Y2Network::Widgets::WirelessNetworks.new
      end

      # Scans for wireless networks
      #
      # @return [Array<WirelessNetwork>] List of found wireless networks
      # @see Y2Network::WirelessNetwork.all
      def find_networks
        found_networks = nil
        Yast2::Feedback.show(
          _("Scanning for wireless networks..."), headline: _("Scanning network")
        ) do
          found_networks = Y2Network::WirelessNetwork.all(@interface.name)
          log.info("Found networks: #{found_networks.map(&:essid)}")
        end

        found_networks
      end
    end
  end
end
