# Copyright (c) [2020] SUSE LLC
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

require "cwm"

module Y2Network
  module Widgets
    # Widget that permits to modify the hostname of the given object
    class Hostname < CWM::InputField
      # Constructor
      #
      # @param settings [Object]
      # @param empty_allowed [Boolean] whether an empty hostname should be
      #   valid or not
      def initialize(settings, empty_allowed: true)
        textdomain "network"

        @settings = settings
        @empty_allowed = empty_allowed
      end

      def init
        self.value = @settings.hostname.to_s
      end

      def label
        _("&Hostname")
      end

      def store
        @settings.hostname = value
      end

      def validate
        Yast.import "Hostname"
        return true if empty_allowed? && value.to_s.empty?

        Yast::Hostname.CheckFQ(value)
      end

    private

      # Return whether an empty value is allowed or not
      #
      # @return [Boolean]
      def empty_allowed?
        @empty_allowed
      end
    end
  end
end
