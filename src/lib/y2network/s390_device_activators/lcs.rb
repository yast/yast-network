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

require "y2network/s390_device_activators/ctc"

module Y2Network
  module S390DeviceActivators
    # The Lcs device activator is based in Ctc as both have two group device
    # channels (read and write).
    #
    # In the past they shared also the configure command 'ctc_configure' and
    # the 'protocol' attribute was needed, but as the configuration has
    # been moved to 'chzdev' command it is not the case anymore.
    class Lcs < Ctc
      def configure_attributes
        return [] unless builder.timeout

        ["lancmd_timeout=#{builder.timeout}"]
      end
    end
  end
end
