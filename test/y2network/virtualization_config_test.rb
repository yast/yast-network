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
require_relative "../test_helper"
require "y2network/virtualization_config"

describe Y2Network::VirtualizationConfig do
  let(:virt_config) { described_class.new(config) }
  let(:config) do
    Y2Network::Config.new(interfaces: interfaces, connections: connections, source: :testing)
  end
  let(:connections) do
    Y2Network::ConnectionConfigsCollection.new([eth0_conn, eth1_conn])
  end
  let(:ip) do
    Y2Network::ConnectionConfig::IPConfig.new(Y2Network::IPAddress.new("192.168.122.2", 24))
  end
  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:eth1) { Y2Network::Interface.new("eth1") }
  let(:eth2) { Y2Network::Interface.new("eth2") }
  let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, eth1, eth2]) }
  let(:eth1_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.interface = "eth1"
      conn.name = "eth1"
      conn.bootproto = :dhcp
      conn.startmode = Y2Network::Startmode.create("auto")
    end
  end

  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.interface = "eth0"
      conn.name = "eth0"
      conn.startmode = Y2Network::Startmode.create("auto")
      conn.bootproto = :static
      conn.ip = ip
    end
  end

  before do
    allow(virt_config).to receive(:connected_and_bridgeable?).and_return(false)
    allow(virt_config).to receive(:connected_and_bridgeable?).with(anything, eth0).and_return(true)
    allow(virt_config).to receive(:connected_and_bridgeable?).with(anything, eth1).and_return(true)
  end

  describe ".bridgeable_candidates" do
    it "selects the interfaces that are connected and bridgeable" do
      candidates = virt_config.bridgeable_candidates
      expect(candidates.size).to eq(2)
      expect(candidates).to_not include(eth2)
      expect(candidates).to include(eth0, eth1)
    end
  end

  describe ".create" do
    before do
      Y2Network::Config.add(:yast, config)
    end

    context "when there are some interfaces that are connected and bridgeable" do
      it "creates a bridge from each of them" do
        virt_config.create
        expect(config.connections.size).to eq(4)
        expect(config.connections.by_name("br0")).to_not be_nil
      end

      it "copies the connection configuration of the interface to the bridge" do
        virt_config.create
        bridge = config.connections.by_name("br0")
        expect(bridge.name).to eq("br0")
        expect(bridge.ip.address.to_s).to eq("192.168.122.2/24")
      end

      it "adds the interface as a port member of the new bridge" do
        virt_config.create
        bridge = config.connections.by_name("br1")
        expect(bridge.ports).to eq(["eth1"])
      end

      it "returns true" do
        expect(virt_config.create).to eq(true)
      end
    end

    context "when there are no connected and bridgeable interfaces" do
      it "returns false" do
        allow(virt_config).to receive(:bridgeable_candidates).and_return([])
        expect(virt_config.create).to eq(false)
      end
    end
  end
end
