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

require "y2network/wicked/connection_config_writers/ethernet"
require "y2network/boot_protocol"
require "y2network/startmode"
require "cfa/interface_file"
require "y2network/connection_config/ethernet"
require "y2network/connection_config/ip_config"

describe Y2Network::Wicked::ConnectionConfigWriters::Ethernet do
  subject(:handler) { described_class.new(file) }

  let(:scr_root) { Dir.mktmpdir }

  around do |example|

    FileUtils.cp_r(File.join(DATA_PATH, "scr_read", "etc"), scr_root)
    change_scr_root(scr_root, &example)
  ensure
    FileUtils.remove_entry(scr_root)

  end

  let(:ip) do
    Y2Network::ConnectionConfig::IPConfig.new(
      Y2Network::IPAddress.from_string("192.168.122.1/24"),
      id: "", broadcast: Y2Network::IPAddress.from_string("192.168.122.255")
    )
  end

  let(:ip_alias) do
    Y2Network::ConnectionConfig::IPConfig.new(
      Y2Network::IPAddress.from_string("10.0.0.1/8"),
      id: "_0", label: "my-label", remote_address: Y2Network::IPAddress.from_string("10.0.0.2")
    )
  end

  let(:all_ips) { [ip, ip_alias] }

  let(:conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |c|
      c.name = "eth0"
      c.interface = "eth0"
      c.description = "Ethernet Card 0"
      c.bootproto = Y2Network::BootProtocol::STATIC
      c.ip = ip
      c.ip_aliases = [ip_alias]
      c.startmode = Y2Network::Startmode.create("auto")
      c.hostname = "foo"
      c.dhclient_set_hostname = true
    end
  end

  let(:file) { CFA::InterfaceFile.find(conn.interface) }

  describe "#write" do
    it "updates common properties" do
      handler.write(conn)
      expect(file).to have_attributes(
        name:                  conn.description,
        bootproto:             "static",
        startmode:             "auto",
        dhclient_set_hostname: "yes"
      )
    end

    it "sets IP configuration attributes" do
      handler.write(conn)
      expect(file).to have_attributes(
        ipaddrs:        { "" => ip.address, "_0" => ip_alias.address },
        broadcasts:     { "" => ip.broadcast, "_0" => nil },
        remote_ipaddrs: { "" => nil, "_0" => ip_alias.remote_address },
        labels:         { "" => nil, "_0" => "my-label" }
      )
    end

    context "when using dhcp" do
      before do
        conn.bootproto = Y2Network::BootProtocol::DHCP
      end

      it "only writes ip aliases" do
        handler.write(conn)
        expect(file.ipaddrs[""]).to be_nil
        expect(file.ipaddrs["_0"]).to eq(ip_alias.address)
      end
    end

    it "sets the hostname" do
      expect(Yast::Host).to receive(:Update).with("", "foo", ip.address.address.to_s)
      handler.write(conn)
    end
  end
end
