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

require_relative "../../test_helper"
require "y2network/sysconfig/interfaces_reader"
require "y2network/udev_rule_part"

describe Y2Network::Sysconfig::InterfacesReader do
  subject(:reader) { described_class.new }
  let(:netcards) do
    [eth0]
  end

  let(:eth0) do
    {
      "active" => true, "dev_name" => "eth0", "mac" => "00:12:34:56:78:90", "name" => "Ethernet Connection",
      "type" => "eth"
    }
  end

  let(:udev_rule) do
    Y2Network::UdevRule.new(
      [
        Y2Network::UdevRulePart.new("ATTR{address}", "==", "00:12:34:56:78"),
        Y2Network::UdevRulePart.new("ACTION", "=", "eth0")
      ]
    )
  end

  let(:configured_interfaces) { ["lo", "eth0"] }
  TYPES = { "eth0" => "eth" }.freeze

  before do
    allow(Yast::LanItems).to receive(:Hardware).and_return(netcards)
    allow(Yast::SCR).to receive(:Dir).with(Yast::Path.new(".network.section"))
      .and_return(configured_interfaces)
    allow(Yast::SCR).to receive(:Dir).and_call_original
    allow(Yast::NetworkInterfaces).to receive(:GetTypeFromSysfs) { |n| TYPES[n] }
    allow(Y2Network::UdevRule).to receive(:find_for).and_return(udev_rule)
  end

  around { |e| change_scr_root(File.join(DATA_PATH, "scr_read"), &e) }

  describe "#interfaces" do
    it "reads physical interfaces" do
      interfaces = reader.interfaces
      expect(interfaces.by_name("eth0")).to_not be_nil
    end

    it "sets the renaming mechanism" do
      eth0 = reader.interfaces.by_name("eth0")
      expect(eth0.renaming_mechanism).to eq(:mac)
    end

    it "reads wifi interfaces"
    it "reads bridge interfaces"
    it "reads bonding interfaces"
    it "reads interfaces configuration"

    context "when a connection for a not existing device is found" do
      let(:configured_interfaces) { ["lo", "eth0", "eth1"] }

      context "and it is a virtual connection" do
        it "creates a virtual interface" do
          vlan = reader.interfaces.by_name("eth0.100")
          expect(vlan).to_not be_nil
          expect(vlan).to be_a Y2Network::VirtualInterface
        end
      end

      context "and it is not a virtual connection" do
        it "creates a fake interface" do
          eth1 = reader.interfaces.by_name("eth1")
          expect(eth1).to be_a Y2Network::FakeInterface
        end
      end
    end
  end

  describe "#connections" do
    it "reads ethernet connections" do
      connections = reader.connections
      conn = connections.by_name("eth0")
      expect(conn.interface).to eq("eth0")
    end
  end
end
