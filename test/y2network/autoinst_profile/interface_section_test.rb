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
require "y2network/autoinst_profile/interface_section"
require "y2network/connection_config/ip_config"

describe Y2Network::AutoinstProfile::InterfaceSection do
  subject(:section) { described_class.new }

  describe ".new_from_network" do
    let(:config) do
      Y2Network::ConnectionConfig::Ethernet.new.tap do |c|
        c.bootproto = Y2Network::BootProtocol::STATIC
        c.startmode = Y2Network::Startmode.create("ifplugd")
        c.startmode.priority = 50
        c.firewall_zone = "DMZ"
        c.ethtool_options = "test=1"
        c.interface = "eth0"
        c.ip = Y2Network::ConnectionConfig::IPConfig.new(
          Y2Network::IPAddress.from_string("10.100.0.1/24")
        )
        c.ip_aliases = [
          Y2Network::ConnectionConfig::IPConfig.new(
            Y2Network::IPAddress.from_string("10.100.0.1/24"), label: "test"
          ),
          Y2Network::ConnectionConfig::IPConfig.new(
            Y2Network::IPAddress.from_string("10.100.0.2/24"), label: "test1"
          )
        ]
      end
    end

    let(:parent) { double("parent section") }

    it "initializes values properly" do
      section = described_class.new_from_network(config)
      expect(section.bootproto).to eq("static")
      expect(section.ipaddr).to eq("10.100.0.1")
      expect(section.prefixlen).to eq("24")
      expect(section.aliases).to eq(
        "alias0" => { "IPADDR" => "10.100.0.1", "PREFIXLEN" => "24", "LABEL" => "test" },
        "alias1" => { "IPADDR" => "10.100.0.2", "PREFIXLEN" => "24", "LABEL" => "test1" }
      )
    end

    it "sets the parent section" do
      section = described_class.new_from_network(config, parent)
      expect(section.parent).to eq(parent)
    end
  end

  describe ".new_from_hashes" do
    let(:hash) do
      {
        "bootproto" => "dhcp4",
        "device"    => "eth0",
        "startmode" => "auto"
      }
    end

    let(:parent) { double("parent section") }

    it "loads properly boot protocol" do
      section = described_class.new_from_hashes(hash)
      expect(section.bootproto).to eq "dhcp4"
    end

    it "sets the parent section" do
      section = described_class.new_from_hashes(hash, parent)
      expect(section.parent).to eq(parent)
    end
  end

  describe "#to_hashes" do
    subject(:section) do
      described_class.new_from_hashes(
        "device"  => "eth0",
        "aliases" => { "alias0" => { "IPADDR" => "10.100.0.1", "PREFIXLEN" => "24" } }
      )
    end

    it "exports the aliases key" do
      expect(section.to_hashes["aliases"]).to eq(section.aliases)
    end

    context "when the list of aliases is empty" do
      subject(:section) do
        described_class.new_from_hashes("device" => "eth0", "aliases" => {})
      end

      it "does not export the aliases key" do
        expect(section.to_hashes).to_not have_key("aliases")
      end
    end
  end

  describe "#wireless_keys" do
    it "returns array" do
      section = described_class.new_from_hashes({})
      expect(section.wireless_keys).to be_a Array
    end

    it "return each defined wireless key" do
      hash = {
        "wireless_key1" => "test1",
        "wireless_key3" => "test3"
      }

      section = described_class.new_from_hashes(hash)
      expect(section.wireless_keys).to eq ["test1", "test3"]
    end
  end

  describe "#bonding_slaves" do
    it "returns array" do
      section = described_class.new_from_hashes({})
      expect(section.bonding_slaves).to be_a Array
    end

    it "return each defined wireless key" do
      hash = {
        "bonding_slave1" => "eth0",
        "bonding_slave3" => "eth1"
      }

      section = described_class.new_from_hashes(hash)
      expect(section.bonding_slaves).to eq ["eth0", "eth1"]
    end
  end
end
