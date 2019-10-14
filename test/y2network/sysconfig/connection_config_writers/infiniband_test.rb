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

require "y2network/sysconfig/connection_config_writers/infiniband"
require "y2network/startmode"
require "y2network/boot_protocol"
require "y2network/ipoib_mode"
require "y2network/connection_config/infiniband"
require "y2network/connection_config/ip_config"

describe Y2Network::Sysconfig::ConnectionConfigWriters::Infiniband do
  subject(:handler) { described_class.new(file) }

  let(:scr_root) { Dir.mktmpdir }

  around do |example|

    FileUtils.cp_r(File.join(DATA_PATH, "scr_read", "etc"), scr_root)
    change_scr_root(scr_root, &example)
  ensure
    FileUtils.remove_entry(scr_root)

  end

  let(:ip) do
    Y2Network::ConnectionConfig::IPConfig.new(Y2Network::IPAddress.from_string("192.168.20.1/24"))
  end

  let(:conn) do
    Y2Network::ConnectionConfig::Infiniband.new.tap do |c|
      c.name = "ib0"
      c.interface = "ib0"
      c.description = ""
      c.ipoib_mode =  Y2Network::IpoibMode::CONNECTED
      c.ip = ip
      c.startmode = Y2Network::Startmode.create("auto")
      c.bootproto = Y2Network::BootProtocol::STATIC
    end
  end

  let(:file) { Y2Network::Sysconfig::InterfaceFile.new(conn.name) }

  describe "#write" do
    it "writes the 'ipoib_mode' attribute" do
      handler.write(conn)
      expect(file).to have_attributes(
        ipoib_mode: "connected"
      )
    end
  end
end
