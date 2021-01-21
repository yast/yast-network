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

require "y2network/wicked/connection_config_readers/base"

module Y2Network
  module Wicked
    module ConnectionConfigReaders
      # This class is able to build a ConnectionConfig::Ctc object given a
      # Wicked::InterfaceFile object.
      class Ctc < Base
        LIST_CMD = "/sbin/lszdev".freeze

        def update_connection_config(conn)
          update_protocol(conn) if update_device_id(conn)
        end

      private

        def device_id_from(conn)
          return if conn.interface.to_s.empty?

          cmd = [LIST_CMD, "ctc", "-c", "id", "-n", "--by-interface=#{conn.interface}"]

          id = Yast::Execute.stdout.on_target!(cmd).chomp
          id.to_s.empty? ? nil : id
        end

        def update_device_id(conn)
          id = device_id_from(conn)
          return unless id

          conn.read_channel, conn.write_channel = id.split(":")
        end

        def update_protocol(conn)
          protocol_file = "/sys/class/net/#{conn.interface}/device/protocol"
          conn.protocol = ::File.exist?(protocol_file) ? ::File.read(protocol_file).strip.to_i : nil
        end
      end
    end
  end
end
