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

require "yast"
require "cwm"

module Y2Network
  module Widgets
    # This class allows the user to select which hardware information
    # should be taken into account when renaming a device
    class RenameHwinfo < CWM::CustomWidget
      # @return [Hwinfo,nil] Hardware information to consider
      attr_reader :value

      # Constructor
      #
      # @param builder [InterfaceConfigBuilder] Interface configuration builder object
      def initialize(builder)
        textdomain "network"
        @builder = builder

        interface = builder.interface
        return unless interface.hardware # FIXME: handle interfaces with no hardware information
        @hwinfo = interface.hardware || Y2Network::Hwinfo.new({})
        @mac = @hwinfo.mac
        @bus_id = @hwinfo.busid
      end

      # @see CWM::AbstractWidget
      def init
        udev_attr = @hwinfo.busid && !@hwinfo.busid.empty? ? :bus_id : :mac
        Yast::UI.ChangeWidget(Id(:udev_type), :Value, udev_attr)
      end

      # @see CWM::AbstractWidget
      def store
        @value = current_value
      end

      # @see CWM::CustomWidget
      def contents
        VBox(
          _("Base Udev Rule On"),
          RadioButtonGroup(
            Id(:udev_type),
            VBox(
              # make sure there is enough space (#367239)
              HSpacing(30),
              Left(
                RadioButton(
                  Id(:mac),
                  _("MAC address: %s") % @mac
                )
              ),
              Left(
                RadioButton(
                  Id(:bus_id),
                  _("BusID: %s") % @bus_id
                )
              )
            )
          )
        )
      end

    private

      def current_value
        [selected_udev_type, current_hwinfo]
      end

      # Determines the hardware information used to match
      #
      # @return [HWinfo]
      def current_hwinfo
        case selected_udev_type
        when :mac
          args = { mac: @mac }
        when :bus_id
          args = { busid: @bus_id }
          args[:dev_port] = @dev_port if @dev_port
        end
        Y2Network::Hwinfo.new(args)
      end

      def selected_udev_type
        Yast::UI.QueryWidget(Id(:udev_type), :Value)
      end
    end
  end
end