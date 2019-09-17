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

require "y2network/connection_config/base"

module Y2Network
  module ConnectionConfig
    # Configuration for qeth connections
    class Qeth < Base
      # For CCW devices and CCW group devices, this device ID is the device
      # bus-ID.
      #
      # The device bus-ID is of the format 0.<subchannel_set_ID>.<devno>,
      # for example, 0.0.8000.
      #
      # The qeth device driver requires three I/O subchannels for each
      # HiperSockets CHPID or OSA-ExpressCHPID in QDIO mode.
      #
      # One subchannel is for control reads, one for control writes, and the
      # third is for data.
      #
      # @example enable a qeth interface (persistently)
      #   chzdev --enable qeth 0.0.a000:0.0.a001:0.0.a002
      #
      # @see https://www.ibm.com/developerworks/linux/linux390/index.html
      # @return [String] read bus id
      attr_accessor :read_channel
      # @return [String] write bus id
      attr_accessor :write_channel
      # @return [String] data bus id
      attr_accessor :data_channel
      # @return [Boolean] whether layer2 is enabled or not
      attr_accessor :layer2
      # @return [Integer] port number (0 or 1)
      attr_accessor :port_number

      # Constructor
      def initialize
        super()
        @layer2 = false
        @port_number = 0
      end

      def ==(other)
        return false unless super

        [:read_channel, :write_channel, :data_channel, :layer2, :port_number].all? do |method|
          public_send(method) == other.public_send(method)
        end
      end
    end
  end
end
