# Copyright (c) [2021] SUSE LLC
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

require_relative "../../../test_helper"
require "y2network/network_manager/connection_config_writers/bridge"
require "cfa/nm_connection"
require "y2network/boot_protocol"
require "y2network/startmode"
require "y2network/connection_config/bridge"

describe Y2Network::NetworkManager::ConnectionConfigWriters::Bridge do
  subject(:handler) { described_class.new(file) }
  let(:file) { CFA::NmConnection.new("br0.nm_connection") }

  let(:conn) do
    Y2Network::ConnectionConfig::Bridge.new.tap do |c|
      c.interface = "br0"
      c.description = "Bridge 0"
      c.startmode = Y2Network::Startmode.create("auto")
      c.bootproto = Y2Network::BootProtocol::DHCP
      c.stp = true
      c.forward_delay = 2
      c.ports = ["eth0"]
    end
  end

  describe "#write" do
    it "sets device and IP relevant attributes" do
      handler.write(conn)
      expect(file.connection["type"]).to eql("bridge")
      expect(file.bridge["stp"]).to eql("true")
      expect(file.bridge["forward-delay"]).to eql("2")
      expect(file.ipv4["method"]).to eql("auto")
      expect(file.ipv6["method"]).to eql("auto")
    end
  end
end
