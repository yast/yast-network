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

require "y2network/wicked/connection_config_writers/bonding"
require "cfa/interface_file"
require "y2network/startmode"
require "y2network/connection_config/bonding"

describe Y2Network::Wicked::ConnectionConfigWriters::Bonding do
  subject(:handler) { described_class.new(file) }

  let(:conn) do
    Y2Network::ConnectionConfig::Bonding.new.tap do |c|
      c.name = "bond0"
      c.interface = "bond0"
      c.description = ""
      c.startmode = Y2Network::Startmode.create("auto")
      c.bootproto = Y2Network::BootProtocol::DHCP
      c.slaves = ["eth0", "eth1"]
      c.options = "mode=active-backup miimon=100"
    end
  end

  let(:file) { CFA::InterfaceFile.new(conn.name) }

  describe "#write" do
    it "writes common properties" do
      handler.write(conn)
      expect(file).to have_attributes(
        startmode: "auto",
        bootproto: "dhcp"
      )
    end

    it "writes bonding properties" do
      handler.write(conn)
      expect(file).to have_attributes(
        bonding_slaves:      { 0 => "eth0", 1 => "eth1" },
        bonding_module_opts: "mode=active-backup miimon=100"
      )
    end
  end
end
