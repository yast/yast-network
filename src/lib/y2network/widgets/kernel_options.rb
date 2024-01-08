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

Yast.import "Label"

module Y2Network
  module Widgets
    class KernelOptions < CWM::InputField
      # Constructor
      #
      # @param options [String] Driver options
      def initialize(options)
        super()
        textdomain "network"
        @options = options
      end

      def label
        Yast::Label.Options
      end

      def help
        _(
          "<p>Additionally, specify <b>Options</b> for the kernel module. Use this\n" \
          "format: <i>option</i>=<i>value</i>. Each entry should be space-separated, " \
          "for example: <i>io=0x300 irq=5</i>. <b>Note:</b> If two cards are \n" \
          "configured with the same module name, the options will be merged while saving.</p>\n"
        )
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = @options
      end
    end
  end
end
