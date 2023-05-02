# Copyright (c) [2023] SUSE LLC
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
require "cwm/common_widgets"
require "abstract_method"
require "y2network/sequences/interface"
require "y2network/s390_group_device"
require "y2network/dialogs/s390_device_activation"

Yast.import "Label"
Yast.import "Lan"

module Y2Network
  module Widgets
    class InterfaceButton < CWM::PushButton
      include Yast::Logger

      abstract_method :label
      abstract_method :help
      # @param table [InterfacesTable]
      def initialize(table)
        textdomain "network"

        @table = table
      end

      # @see CWM::AbstractWidget#init
      def init
        disable? ? disable : enable
      end

      def config
        Yast::Lan.yast_config
      end

      def connection_config
        config.connections.by_name(@table.value)
      end

      def item
        connection_config || selected_interface(config)
      end

      def selected_interface(config)
        config.interfaces.by_name(@table.value) || config.s390_devices.by_id(@table.value)
      end

      def disable?
        return true unless @table.value
        return true unless connection_config
      end
    end
  end
end
