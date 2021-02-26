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
    # Channel selector widget
    class WirelessChannel < CWM::ComboBox
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings

        textdomain "network"
      end

      def init
        self.value = @settings.channel.to_s
      end

      def store
        @settings.channel = value.empty? ? nil : value.to_i
      end

      def label
        _("&Channel")
      end

      def opt
        [:hstretch]
      end

      def items
        # FIXME: different protocol has different number of channels, we need to reflect it somehow
        # 1..14 is number of channels available in legal range for wireless
        1.upto(14).map { |c| [c.to_s, c.to_s] }.prepend(["", _("Automatic")])
      end
    end

    # bit rate selection widget
    class WirelessBitRate < CWM::ComboBox
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings

        textdomain "network"
      end

      def opt
        [:hstretch, :editable]
      end

      def label
        _("B&it Rate")
      end

      def init
        self.value = @settings.bitrate.to_s
      end

      def store
        @settings.bitrate = value.empty? ? nil : value.to_f
      end

      def items
        bitrates.map { |b| [b.to_s, b.to_s] }.prepend(["", _("Automatic")])
      end

    # TODO: help text with units (Mb/s)

    private

      def bitrates
        [54, 48, 36, 24, 18, 12, 11, 9, 6, 5.5, 2, 1]
      end
    end

    # Widget to select access point if site consist of multiple ones
    class WirelessAccessPoint < CWM::InputField
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        textdomain "network"
      end

      def opt
        [:hstretch]
      end

      def label
        _("&Access Point")
      end

      def init
        self.value = @settings.access_point
      end

      def store
        @settings.access_point = value
      end

      # TODO: help text with explanation what exactly is needed
      # TODO: validation of MAC address
    end

    # widget to set Scan mode
    class WirelessAPScanMode < CWM::IntField
      # @param settings [Y2network::InterfaceConfigBuilder]
      def initialize(settings)
        @settings = settings
        textdomain "network"
      end

      def opt
        [:hstretch]
      end

      def label
        _("AP ScanMode")
      end

      def minimum
        0
      end

      def maximum
        2
      end

      def init
        self.value = @settings.ap_scanmode.to_i
      end

      def store
        @settings.ap_scanmode = value
      end

      # TODO: help text
    end
  end
end
