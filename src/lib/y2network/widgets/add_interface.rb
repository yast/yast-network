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
require "y2network/sequences/interface"

Yast.import "Label"

module Y2Network
  module Widgets
    class AddInterface < CWM::PushButton
      def initialize
        textdomain "network"
      end

      def label
        Yast::Label.AddButton
      end

      def handle
        Y2Network::Sequences::Interface.new.add
        :redraw
      end

      def help
        # TRANSLATORS: Help for 'Add' interface configuration button
        _(
          "<p><b><big>Adding a Network Card:</big></b><br>\nPress " \
          "<b>Add</b> to configure a new network card manually.</p>\n"
        )
      end
    end
  end
end
