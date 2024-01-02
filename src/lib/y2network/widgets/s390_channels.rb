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

require "cwm/custom_widget"
require "cwm/common_widgets"

module Y2Network
  module Widgets
    # A container widget for setting the QETH and HSI device channels (read,
    # write and control)
    class S390Channels < CWM::CustomWidget
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        super()
        textdomain "network"
        @settings = settings
      end

      # @see CWM::AbstractWidget
      def label
        ""
      end

      # @see CWM::AbstractWidget
      def contents
        HBox(
          S390ReadChannel.new(@settings),
          HSpacing(1),
          S390WriteChannel.new(@settings),
          HSpacing(1),
          S390DataChannel.new(@settings)
        )
      end
    end

    # Widget for setting the s390 device read channel
    class S390ReadChannel < CWM::InputField
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        super()
        textdomain "network"
        @settings = settings
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @settings.read_channel
        disable
      end

      # @see CWM::AbstractWidget
      def opt
        [:hstretch]
      end

      # @see CWM::AbstractWidget
      def label
        _("&Read Channel")
      end

      # @see CWM::AbstractWidget
      def store
        @settings.read_channel = value
      end
    end

    # Widget for setting the s390 device write channel
    class S390WriteChannel < CWM::InputField
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        super()
        textdomain "network"
        @settings = settings
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @settings.write_channel
        disable
      end

      # @see CWM::AbstractWidget
      def opt
        [:hstretch]
      end

      # @see CWM::AbstractWidget
      def label
        _("&Write Channel")
      end

      # @see CWM::AbstractWidget
      def store
        @settings.write_channel = value
      end
    end

    # Widget for setting the s390 device data channel
    class S390DataChannel < CWM::InputField
      # Constructor
      #
      # @param settings [Y2Network::InterfaceConfigBuilder]
      def initialize(settings)
        super()
        textdomain "network"
        @settings = settings
      end

      # @see CWM::AbstractWidget
      def init
        self.value = @settings.data_channel
        disable
      end

      # @see CWM::AbstractWidget
      def opt
        [:hstretch]
      end

      # @see CWM::AbstractWidget
      def label
        _("Control Channel")
      end

      # @see CWM::AbstractWidget
      def store
        @settings.data_channel = value
      end
    end
  end
end
