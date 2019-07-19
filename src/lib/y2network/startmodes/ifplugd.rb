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

require "y2network/startmode"

module Y2Network
  module Startmodes
    class Ifplugd < Startmode
      include Yast::I18n
      attr_accessor :priority

      def initialize
        textdomain "network"

        @priority = 0

        super("ifplugd")
      end

      def to_human_string
        _("On Cable Connection")
      end

      def ==(other)
        name == other.name && priority == other.priority
      end
    end
  end
end
