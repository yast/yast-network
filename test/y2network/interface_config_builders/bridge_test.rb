#!/usr/bin/env rspec

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

require "yast"
require "y2network/interface_config_builders/bridge"

describe Y2Network::InterfaceConfigBuilders::Bridge do
  let(:config) { Y2Network::Config.new(source: :test, connections: connections) }

  before do
    allow(Y2Network::Config)
      .to receive(:find)
      .with(:yast)
      .and_return(config)
  end

  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Bridge.new
    res.name = "br0"
    res
  end

  let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn]) }
  let(:interfaces) { [eth0, eth1] }
  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:eth1) { Y2Network::Interface.new("eth1") }
  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.name = "eth0"
      conn.interface = "eth0"
      conn.bootproto = Y2Network::BootProtocol::NONE
    end
  end

  describe "#type" do
    it "returns bridge type" do
      expect(subject.type).to eq Y2Network::InterfaceType::BRIDGE
    end
  end

  describe "#bridgable_interfaces" do
    # TODO: better and more reasonable test when we have easy way how to describe configuration
    it "returns array" do
      expect(subject.bridgeable_interfaces).to be_a(::Array)
    end
  end

  describe "#require_adaptation?" do
    it "returns boolean" do
      expect(subject.require_adaptation?([])).to eq false
    end

    context "when there is no bridge port configured" do
      it "returns false" do
        expect(subject.require_adaptation?(["eth1"])).to eql(false)
      end
    end

    context "when there is at least one bridge port configured without a none bootproto" do
      let(:eth0_conn) do
        Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
          conn.name = "eth0"
          conn.bootproto = Y2Network::BootProtocol::STATIC
          conn.interface = "eth0"
        end
      end

      it "returns true" do
        expect(subject.require_adaptation?(["eth0"])).to eql(true)
      end
    end
  end
end
