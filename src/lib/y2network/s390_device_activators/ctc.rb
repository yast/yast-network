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

require "y2network/s390_device_activator"

module Y2Network
  module S390DeviceActivators
    # This class is responsible of activating CTC group devices.
    class Ctc < S390DeviceActivator
      def_delegators :@builder,
        :read_channel, :read_channel=,
        :write_channel, :write_channel=,
        :hwinfo, :protocol

      def configure_attributes
        return [] unless builder.protocol

        ["protocol=#{builder.protocol}"]
      end

      # Modifies the read and write channel from the the device id
      def propose_channels
        id = builder.name
        return unless id

        self.read_channel, self.write_channel = id.split(":")
      end

      def propose!
        propose_channels unless device_id
      end
    end
  end
end
