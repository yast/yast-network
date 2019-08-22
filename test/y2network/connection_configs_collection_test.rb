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
require "y2network/connection_configs_collection"
require "y2network/connection_config/ethernet"
require "y2network/connection_config/wireless"

describe Y2Network::ConnectionConfigsCollection do
  subject(:collection) { described_class.new(connections) }

  let(:connections) { [eth0, wlan0] }
  let(:eth0) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.name = "eth0"
      conn.interface = "eth0"
    end
  end
  let(:wlan0) { Y2Network::ConnectionConfig::Wireless.new.tap { |c| c.name = "wlan0" } }

  describe "#by_name" do
    it "returns the connection configuration with the given name" do
      expect(collection.by_name("eth0")).to eq(eth0)
    end

    context "when name is not defined" do
      it "returns nil" do
        expect(collection.by_name("eth1")).to be_nil
      end
    end
  end

  describe "#by_interface" do
    it "returns the connection configurations associated to the given interface name" do
      expect(collection.by_interface("eth0")).to eq([eth0])
    end
  end

  describe "#add_or_update" do
    let(:eth0_1) { Y2Network::ConnectionConfig::Ethernet.new.tap { |c| c.name = "eth0" } }

    context "when a connection configuration having the same name exists" do
      it "replaces the existing configuration with the new one" do
        collection.add_or_update(eth0_1)
        expect(collection.by_name("eth0")).to be(eth0_1)
        expect(collection.size).to eq(2)
      end
    end

    context "if a connection configuration having the same name does not exist" do
      let(:wlan1) { Y2Network::ConnectionConfig::Wireless.new.tap { |c| c.name = "wlan1" } }

      it "adds the configuration to the collection" do
        collection.add_or_update(wlan1)
        expect(collection.by_name("wlan1")).to be(wlan1)
        expect(collection.size).to eq(3)
      end
    end
  end

  describe "#remove" do
    context "when a connection configuration having the same name exists" do
      it "removes the configuration from the collection" do
        collection.remove(eth0)
        expect(collection.by_name("eth0")).to be_nil
        expect(collection.size).to eq(1)
      end
    end

    context "when a name is given, instead of a connection configuration" do
      it "removes the configuration with the given name" do
        collection.remove("eth0")
        expect(collection.by_name("eth0")).to be_nil
        expect(collection.size).to eq(1)
      end
    end

    context "when a connection configuration having the same name does not exists" do
      let(:wlan1) { Y2Network::ConnectionConfig::Wireless.new.tap { |c| c.name = "wlan1" } }

      it "does not modify the collection" do
        expect { collection.remove("wlan1") }.to_not change { collection.size }
      end
    end
  end
end
