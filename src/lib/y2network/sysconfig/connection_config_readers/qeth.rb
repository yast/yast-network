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

require "y2network/sysconfig/connection_config_readers/base"

module Y2Network
  module Sysconfig
    module ConnectionConfigReaders
      # This class is able to build a ConnectionConfig::Qeth object given a
      # Sysconfig::InterfaceFile object.
      class Qeth < Base
        LIST_CMD = "/sbin/lszdev".freeze

        def update_connection_config(conn)
          return unless update_device_id(conn)
          update_layer2(conn)
          update_portno(conn)
          update_ipa_takeover(conn)
        end

      private

        def device_id_from(conn)
          return if conn.interface.to_s.empty?
          cmd = [LIST_CMD, "qeth", "-c", "id", "-n", "--by-interface=#{conn.interface}"]

          id = Yast::Execute.stdout.on_target!(cmd).chomp
          id.to_s.empty? ? nil : id
        end

        def update_device_id(conn)
          id = device_id_from(conn)
          return unless id
          conn.read_channel, conn.write_channel, conn.data_channel = id.split(":")
        end

        def update_layer2(conn)
          layer2_file = "/sys/class/net/#{conn.interface}/device/layer2"
          layer2 = ::File.exist?(layer2_file) ? ::File.read(layer2_file).strip : nil
          conn.layer2 = layer2 ? (layer2 == "1") : nil
        end

        def update_portno(conn)
          portno_file = "/sys/class/net/#{conn.interface}/device/portno"
          conn.port_number = ::File.exist?(portno_file) ? ::File.read(portno_file).strip.to_i : nil
        end

        def update_ipa_takeover(conn)
          ipato_file = "/sys/class/net/#{conn.interface}/device/ipa_takeover/enable"
          ipa_takeover = ::File.exist?(ipato_file) ? ::File.read(ipato_file).strip : nil
          conn.ipa_takeover = ipa_takeover ? (ipa_takeover == "1") : nil
        end
      end
    end
  end
end
