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
require "y2network/config_copier"

module Y2Network
  module NetworkManager
    # This class copies Wicked specific configuration to the target system
    class ConfigCopier < Y2Network::ConfigCopier
      NETWORK_MANAGER = "/etc/NetworkManager".freeze

      def copy
        copy_files_to_target(["*"], File.join(NETWORK_MANAGER, "system-connections"))
      end
    end
  end
end
