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
require "y2network/widgets/udev_rules"
require "y2network/widgets/interface_name"

module Y2Network
  module Widgets
    # Widget to handle interface naming, including udev based renames.
    class InterfaceNaming < ::CWM::CustomWidget
      # Constructor
      #
      # @param builder [Y2Network::InterfaceConfigBuilder] Interface configuration builder object
      def initialize(builder)
        @builder = builder
      end

      # @see CWM::CustomWidget#contents
      def contents
        VBox(widget)
      end

    private

      def udev_based_rename?
        return false unless @builder.interface

        hardware = @builder.interface.hardware
        return false unless hardware

        !!(hardware.mac || hardware.busid)
      end

      # Internal widget
      #
      # It uses an internal widget to handle the rename depending on whether
      # udev based renames are needed or not.
      def widget
        @widget ||= udev_based_rename? ? UdevRules.new(@builder) : InterfaceName.new(@builder)
      end
    end
  end
end
