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

require "cwm/common_widgets"

module Y2Network
  module Widgets
    class KernelModule < CWM::ComboBox
      # Constructor
      #
      # @param names    [Array<String>] Drivers names
      # @param selected [String,nil] Initially selected driver (nil if no driver is selected)
      def initialize(names, selected)
        textdomain "network"
        @names = names
        @selected = selected
        self.widget_id = "kernel_module"
      end

      def label
        _("&Module Name")
      end

      def help
        _(
          "<p><b>Kernel Module</b>. Enter the kernel module (driver) name \n" \
            "for your network device here. If the device is already configured, " \
            "see if there is more than one driver available for\n" \
            "your device in the drop-down list. If necessary, choose a driver " \
            "from the list, but usually the default value works.</p>\n"
        )
      end

      def opt
        [:editable, :notify]
      end

      def items
        @items ||= [["", _("Auto")]] + @names.map { |n| [n, n] }
      end

      def init
        self.value = @selected if @selected
      end

      def value
        ret = super
        (ret == "") ? :auto : ret
      end
    end
  end
end
