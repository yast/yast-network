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

require_relative "../../../test_helper"

require "y2network/sysconfig/connection_config_writers/bridge"
require "cfa/interface_file"
require "y2network/startmode"
require "y2network/boot_protocol"
require "y2network/connection_config/bridge"

describe Y2Network::Sysconfig::ConnectionConfigWriters::Bridge do
  subject(:handler) { described_class.new(file) }

  let(:conn) do
    Y2Network::ConnectionConfig::Bridge.new.tap do |c|
      c.name = "br1"
      c.interface = "br1"
      c.description = ""
      c.startmode = Y2Network::Startmode.create("auto")
      c.bootproto = Y2Network::BootProtocol::DHCP
      c.ports = ["eth0", "eth1"]
      c.stp = false
      c.forward_delay = 5
    end
  end

  let(:file) { CFA::InterfaceFile.new(conn.name) }

  describe "#write" do
    it "writes common properties" do
      handler.write(conn)
      expect(file).to have_attributes(
        name:      conn.description,
        startmode: "auto",
        bootproto: "dhcp"
      )
    end

    it "writes bridge properties" do
      handler.write(conn)
      expect(file).to have_attributes(
        bridge:              "yes",
        bridge_ports:        "eth0 eth1",
        bridge_forwarddelay: 5,
        bridge_stp:          "off"
      )
    end
  end
end
