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
require "cwm/custom_widget"
require "yast2/feedback"

Yast.import "String"

module Y2Network
  module Widgets
    # Widget to setup wifi network essid
    class WirelessEssid < CWM::CustomWidget
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        textdomain "network"
      end

      def contents
        HBox(
          essid,
          VBox(
            VSpacing(1),
            scan
          )
        )
      end

    private

      def essid
        @essid ||= WirelessEssidName.new(@settings)
      end

      def scan
        @scan ||= WirelessScan.new(@settings, update: essid)
      end
    end

    # Widget for network name combobox
    class WirelessEssidName < CWM::ComboBox
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        textdomain "network"
      end

      def label
        _("Ne&twork Name (ESSID)")
      end

      def init
        self.value = @settings.essid.to_s
        Yast::UI.ChangeWidget(Id(widget_id), :ValidChars, valid_chars)
      end

      # allow to use not found name e.g. when scan failed or when network is hidden
      def opt
        [:editable]
      end

      # updates essid list with given array and ensure that previously selected value is preserved
      # @param networks [Array<String>]
      def update_essid_list(networks)
        old_value = value
        change_items(networks.map { |n| [n, n] })
        self.value = old_value
      end

    private

      def valid_chars
        Yast::String.CPrint
      end
    end

    # Button for scan network sites
    class WirelessScan < CWM::PushButton
      # @param settings [Y2network::InterfaceConfigBuilder]
      # @param update [WirelessEssidName]
      def initialize(settings, update:)
        @settings = settings
        @update_widget = update
        textdomain "network"
      end

      def label
        _("Scan Network")
      end

      def handle
        networks = essid_list

        Yast2::Feedback.show("Obtaining essid list", headline: "Scanning network") do |_f|
          networks = essid_list
          log.info("Found networks: #{networks}")
        end

        return unless @update_widget
        @update_widget.update_essid_list(networks)
        nil
      end

    private

      # TODO: own class and do not call directly in widget.
      def essid_list
        command = "#{link_up} && #{scan} | #{grep_and_cut_essid} | #{sort}"

        output = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), command)
        output["stdout"].split("\n")
      end

      def sort
        "/usr/bin/sort -u"
      end

      def grep_and_cut_essid
        "/usr/bin/grep ESSID | /usr/bin/cut -d':' -f2 | /usr/bin/cut -d'\"' -f2"
      end

      def link_up
        "/usr/sbin/ip link set #{interface} up"
      end

      def scan
        "/usr/sbin/iwlist #{interface} scan"
      end

      def interface
        @settings.name
      end
    end
  end
end
