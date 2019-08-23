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
require "y2network/interface_config_builder"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    class Lcs < InterfaceConfigBuilder
      extend Forwardable

      def initialize(config: nil)
        super(type: InterfaceType::LCS, config: config)
      end

      def_delegators :@connection_config,
        :read_channel, :read_channel=,
        :write_channel, :write_channel=,
        :protocol, :protocol=,
        :timeout, :timeout=

      def device_id
        return if read_channel.to_s.empty?

        "#{read_channel}:#{write_channel}"
      end

      def device_id_from(busid)
        cmd = "/sbin/lszdev lcs -c id -n".split(" ")

        Yast::Execute.stdout.on_target!(cmd).split("\n").find do |d|
          d.include? busid
        end
      end

      def configure_attributes
        "protocol=#{protocol} lancmd_timeout=#{timeout.to_i}".split(" ")
      end

      def configure
        cmd = "/sbin/chzdev lcs #{device_id} -e ".split(" ").concat(configure_attributes)

        Yast::Execute.on_target!(*cmd, allowed_exitstatus: 0..255).zero?
      end

      def configured_interface
        cmd = "/sbin/lszdev #{device_id} -c names -n".split(" ")

        Yast::Execute.stdout.on_target!(cmd).chomp
      end

      def propose_channels
        id = device_id_from(hwinfo.busid)
        return unless id
        self.read_channel, self.write_channel = id.split(":")
      end

      def proposal
        propose_channels unless device_id
      end
    end
  end
end
