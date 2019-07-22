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

require "y2network/sysconfig/connection_config_writers/ethernet"
require "y2network/boot_protocol"
require "y2network/startmode"
require "y2network/sysconfig/interface_file"
require "y2network/connection_config/ethernet"
require "y2network/connection_config/ip_config"

describe Y2Network::Sysconfig::ConnectionConfigWriters::Ethernet do
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

  let(:ip_configs) do
    [
      Y2Network::ConnectionConfig::IPConfig.new(
        Y2Network::IPAddress.from_string("192.168.122.1/24"), id:        :default,
                                                              broadcast: Y2Network::IPAddress.from_string("192.168.122.255")
      ),
      Y2Network::ConnectionConfig::IPConfig.new(
        Y2Network::IPAddress.from_string("10.0.0.1/8"), id: "_0",
        label: "my-label", remote_address: Y2Network::IPAddress.from_string("10.0.0.2")
      )
    ]
  end

  let(:conn) do
    instance_double(
      Y2Network::ConnectionConfig::Ethernet,
      interface:   "eth0",
      description: "Ethernet Card 0",
      bootproto:   Y2Network::BootProtocol::STATIC,
      ip_configs:  ip_configs,
      startmode:   Y2Network::Startmode.create("auto")
    )
  end

  let(:file) { Y2Network::Sysconfig::InterfaceFile.find(conn.interface) }

  describe "#write" do
    it "updates common properties" do
      handler.write(conn)
      expect(file).to have_attributes(
        name:      conn.description,
        bootproto: "static",
        startmode: "auto"
      )
    end

    it "sets IP configuration attributes" do
      handler.write(conn)
      expect(file).to have_attributes(
        ipaddrs:        { default: ip_configs[0].address, "_0" => ip_configs[1].address },
        broadcasts:     { default: ip_configs[0].broadcast, "_0" => nil },
        remote_ipaddrs: { default: nil, "_0" => ip_configs[1].remote_address },
        labels:         { default: nil, "_0" => "my-label" }
      )
    end
  end
end
