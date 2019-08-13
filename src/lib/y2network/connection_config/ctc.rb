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
    # Configuration for ctc connections.
    #
    # @note The use of this connection is deprecated or not recommended as it
    #   will not be officially supported in future SLE versions.
    class Ctc < Base
      # For CCW devices and CCW group devices, this device ID is the device
      # bus-ID.
      #
      # The device bus-ID is of the format 0.<subchannel_set_ID>.<devno>,
      # for example, 0.0.8000.
      #
      # The CTCM device driver requires two I/O subchannels for each interface,
      # a read subchannel and a write subchannel
      #
      # @see https://www.ibm.com/developerworks/linux/linux390/index.html
      # @return [String] read bus id
      attr_accessor :read_channel
      # @return [String] write bus id
      attr_accessor :write_channel
      # @return [Integer] connection protocol (0, 1, 3, or 4)
      #   0 Compatibility with peers other than OS/390®.
      #   1 Enhanced package checking for Linux peers.
      #   3 For compatibility with OS/390 or z/OS peers.
      #   4 For MPC connections to VTAM on traditional mainframe operating systems.
      # @see https://www.ibm.com/support/knowledgecenter/en/linuxonibm/com.ibm.linux.z.ljdd/ljdd_t_ctcm_wrk_protocol.html
      # @see https://github.com/SUSE/s390-tools/blob/master/ctc_configure#L16
      attr_accessor :protocol
    end
  end
end
