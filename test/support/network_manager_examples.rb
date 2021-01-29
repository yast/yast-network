# Copyright (c) [2021] SUSE LLC
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
require "y2network/boot_protocol"
require "y2network/ip_address"
require "y2network/startmode"
require "cfa/nm_connection"

RSpec.shared_examples "NetworkManager::ConfigReader" do

  describe "#connection_config (common attributes)" do
    subject(:handler) { described_class.new(file) }

    let(:file) { CFA::NmConnection.new("cable.nmconnection") }

    let(:ipv4) { CFA::AugeasTree.new }
    let(:ipv6) { CFA::AugeasTree.new }
    let(:connection) { hash_to_augeas_tree("id" => "Cable Connection") }

    before do
      allow(file).to receive(:connection).and_return(connection)
      allow(file).to receive(:ipv4).and_return(ipv4)
      allow(file).to receive(:ipv6).and_return(ipv6)
    end

    context "when neither 'ipv4' or 'ipv6' sections contain a 'method' key" do
      it "sets the boot protocol to 'none'" do
        conn = handler.connection_config
        expect(conn.bootproto).to eq(Y2Network::BootProtocol::NONE)
      end
    end

    context "when 'ipv4' and 'ipv6' sections contain the method key set to 'auto'" do
      let(:ipv4) { hash_to_augeas_tree("method" => "auto") }
      let(:ipv6) { hash_to_augeas_tree("method" => "auto") }

      it "sets the boot protocol to 'dhcp'" do
        conn = handler.connection_config
        expect(conn.bootproto).to eq(Y2Network::BootProtocol::DHCP)
      end
    end

    context "when only the 'ipv4' ' sections contain the method key set to 'auto'" do
      let(:ipv4) { hash_to_augeas_tree("method" => "auto") }

      it "sets the boot protocol to 'dhcp4'" do
        conn = handler.connection_config
        expect(conn.bootproto).to eq(Y2Network::BootProtocol::DHCP4)
      end
    end

    context "when only the 'ipv6' ' sections contain the method key set to 'auto'" do
      let(:ipv6) { hash_to_augeas_tree("method" => "auto") }

      it "sets the boot protocol to 'dhcp6'" do
        conn = handler.connection_config
        expect(conn.bootproto).to eq(Y2Network::BootProtocol::DHCP6)
      end
    end

    context "when the 'ipv4' section contain the method key set to 'manual'" do
      let(:ipv4) { hash_to_augeas_tree("method" => "manual") }

      it "sets the 'static' boot protocol" do
        conn = handler.connection_config
        expect(conn.bootproto).to eq(Y2Network::BootProtocol::STATIC)
      end
    end

    context "when the 'ipv6' section contain the method key set to 'manual'" do
      let(:ipv6) { hash_to_augeas_tree("method" => "manual") }

      it "sets the 'static' boot protocol" do
        conn = handler.connection_config
        expect(conn.bootproto).to eq(Y2Network::BootProtocol::STATIC)
      end
    end

    it "sets the connection name and the description" do
      conn = handler.connection_config
      expect(conn.name).to eq("Cable Connection")
      expect(conn.description).to eq("Cable Connection")
    end

    it "sets the interface to nil" do
      conn = handler.connection_config
      expect(conn.interface).to be_nil
    end

    it "sets the startmode to 'auto'" do
      conn = handler.connection_config
      expect(conn.startmode).to eq(Y2Network::Startmode.create("auto"))
    end

    context "when autoconnect is disabled" do
      let(:connection) { { "autoconnect" => "false" } }

      it "sets the startmode" do
        conn = handler.connection_config
        expect(conn.startmode).to eq(Y2Network::Startmode.create("off"))
      end
    end

    context "when IP addresses are defined in the connection file" do
      let(:ipv4) do
        CFA::AugeasTree.new.tap do |tree|
          tree["address1"] = "192.168.1.10/24,192.168.1.1"
          tree["address2"] = "192.168.0.2/8"
        end
      end

      let(:ipv6) do
        CFA::AugeasTree.new.tap do |tree|
          tree["address1"] = "196e:dcc9:e2:6d4c:517a:f474:d729:a574"
        end
      end

      it "sets the IP addresses" do
        conn = handler.connection_config
        expect(conn.ip.address).to eq(Y2Network::IPAddress.from_string("192.168.1.10/24"))

        aliases = conn.ip_aliases.map(&:address)
        expect(aliases).to eq(
          [
            Y2Network::IPAddress.from_string("192.168.0.2/8"),
            Y2Network::IPAddress.from_string("196e:dcc9:e2:6d4c:517a:f474:d729:a574")
          ]
        )
      end
    end
  end
end
