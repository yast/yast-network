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
require "y2network/interface_type"
require "y2network/type_detector"
require "cfa/interface_file"

module Y2Network
  module Sysconfig
    # Detects type of given interface. New implementation of what was in
    # @see Yast::NetworkInterfaces.GetType
    class TypeDetector < Y2Network::TypeDetector
      class << self
        # Checks wheter iface type can be recognized by interface configuration
        def type_by_config(iface)
          iface_file = CFA::InterfaceFile.find(iface)
          return unless iface_file

          iface_file.load
          iface_file.type
        end
      end
    end
  end
end
