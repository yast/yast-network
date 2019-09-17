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
    # Configuration for lcs connections
    class Lcs < Base
      # Most I/O devices on a s390 system are typically driven through the
      # channel I/O mechanism.
      #
      # The s390-tools provides a set of commands for working with CCW devices
      # and CCW group devices, these commands use a device ID which is the
      # device bus-ID
      #
      # The device bus-ID is of the format 0.<subchannel_set_ID>.<devno>,
      # for example, 0.0.8000.
      #
      # @see https://www.ibm.com/developerworks/linux/linux390/documentation_suse.html
      #
      # The LCS devices drivers requires two I/O subchannels for each interface,
      # a read subchannel and a write subchannel and is very similar to the
      # S390 CTC interface.
      #
      # @return [String] read device bus id
      attr_accessor :read_channel
      # @return [String] write device bus id
      attr_accessor :write_channel
      # @return [Integer] connection protocol (0, 1, 3, or 4)
      #   0 Compatibility with peers other than OS/390®.
      #   1 Enhanced package checking for Linux peers.
      #   3 For compatibility with OS/390 or z/OS peers.
      #   4 For MPC connections to VTAM on traditional mainframe operating systems.
      # @see https://github.com/SUSE/s390-tools/blob/master/ctc_configure#L16
      #
      # # FIXME: At lease in linuxrc the protocol is not needed anymore for lcs
      # interfaces (once replaced ctc_configure by chzdev)
      attr_accessor :protocol
      # The time the driver wait for a reply issuing a LAN command.
      #
      # @return [Integer] lcs lancmd timeout (default 5s)
      # @see https://www.ibm.com/support/knowledgecenter/en/linuxonibm/com.ibm.linux.z.ljdd/ljdd_t_lcs_wrk_timeout.html
      attr_accessor :timeout

      # Constructor
      def initialize
        super()
        @protocol = 0
        @timeout = 5
      end

      def ==(other)
        return false unless super

        [:read_channel, :write_channel, :protocol, :timeout].all? do |method|
          public_send(method) == other.public_send(method)
        end
      end
    end
  end
end
