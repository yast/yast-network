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

require "y2remote/modes/base"
require "y2remote/modes/socket_based"

module Y2Remote
  module Modes
    # Class responsible of handle the systemd socket for vnc web access
    class Web < Base
      include SocketBased

      # Name of the systemd socket
      SOCKET   = "xvnc-novnc".freeze
      # Packages required by the systemd socket
      PACKAGES = ["xorg-x11-Xvnc-novnc"].freeze

      # Return a list of names of the required packages of the running mode
      #
      # @return [Array<String>] list of packages required by the service
      def required_packages
        PACKAGES
      end

      # Name of the socket
      #
      # @return [String] socket name
      def socket_name
        SOCKET
      end
    end
  end
end
