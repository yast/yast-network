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

require "y2network/sysconfig/connection_config_writers/tap"
require "y2network/startmode"
require "y2network/boot_protocol"
require "y2network/connection_config/tap"
require "y2network/connection_config/ip_config"

describe Y2Network::Sysconfig::ConnectionConfigWriters::Tap do
  subject(:handler) { described_class.new(file) }

  def file_content(scr_root, file)
    path = File.join(scr_root, file.path.to_s)
    File.read(path)
  end

  let(:scr_root) { Dir.mktmpdir }

  around do |example|
    begin
      FileUtils.cp_r(File.join(DATA_PATH, "scr_read", "etc"), scr_root)
      change_scr_root(scr_root, &example)
    ensure
      FileUtils.remove_entry(scr_root)
    end
  end

  let(:conn) do
    instance_double(
      Y2Network::ConnectionConfig::Tap,
      name:        "tap1",
      interface:   "tap1",
      owner:       "nobody",
      group:       "nobody",
      description: "",
      bootproto:   Y2Network::BootProtocol::STATIC,
      ip_configs:  [],
      startmode:   Y2Network::Startmode.create("auto")
    )
  end

  let(:file) { Y2Network::Sysconfig::InterfaceFile.new(conn.name) }

  describe "#write" do
    it "writes common properties" do
      handler.write(conn)
      expect(file).to have_attributes(
        bootproto: "static",
        startmode: "auto"
      )
    end

    it "writes 'tunnel' as 'tap'" do
      handler.write(conn)
      expect(file).to have_attributes(
        tunnel: "tap"
      )
    end

    it "writes the 'tunnel_set_owner' and 'tunnel_set_group'" do
      handler.write(conn)
      expect(file).to have_attributes(
        tunnel_set_owner: "nobody",
        tunnel_set_group: "nobody"
      )
    end
  end
end
