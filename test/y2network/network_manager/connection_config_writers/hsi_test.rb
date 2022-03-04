# Copyright (c) [2022] SUSE LLC
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
require "y2network/network_manager/connection_config_writers/hsi"
require "cfa/nm_connection"
require "y2network/boot_protocol"
require "y2network/startmode"
require "y2network/connection_config/bonding"

describe Y2Network::NetworkManager::ConnectionConfigWriters::Hsi do
  subject(:handler) { described_class.new(file) }
  let(:file) { CFA::NmConnection.new("hsi0.nm_connection") }

  let(:conn) do
    Y2Network::ConnectionConfig::Qeth.new.tap do |c|
      c.interface = "hsi0"
      c.description = "Hipersocket connection 0"
      c.startmode = Y2Network::Startmode.create("auto")
      c.bootproto = Y2Network::BootProtocol::STATIC
      c.device_id = "0.0.0800:0.0.0801:0.0.0802"
      c.layer2 = true
      c.port_number = 0
    end
  end

  describe "#write" do
    it "sets device and IP relevant attributes" do
      handler.write(conn)
      expect(file.connection["type"]).to eql("ethernet")
      expect(file.connection["s390-nettype"]).to eql("qeth")
      expect(file.connection["s390-options"]).to eql("layer2=1,portno=0")
      expect(file.connection["s390-subchannels"]).to eql("0.0.0800,0.0.0801,0.0.0802")
    end
  end
end
