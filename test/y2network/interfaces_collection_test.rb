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
require "y2network/interfaces_collection"
require "y2network/physical_interface"
require "y2network/virtual_interface"

describe Y2Network::InterfacesCollection do
  subject(:collection) { described_class.new(interfaces) }

  let(:eth0) { Y2Network::PhysicalInterface.new("eth0") }
  let(:br0) do
    Y2Network::VirtualInterface.new("br0", type: Y2Network::InterfaceType::BRIDGE)
  end
  let(:wlan0) do
    Y2Network::PhysicalInterface.new("wlan0", type: Y2Network::InterfaceType::WIRELESS)
  end
  let(:interfaces) { [eth0, br0, wlan0] }

  describe "#by_name" do
    it "returns the interface with the given name" do
      expect(collection.by_name("eth0")).to eq(eth0)
    end

    context "when name is not defined" do
      let(:wlan0) { Y2Network::PhysicalInterface.new(nil) }
      let(:eth0) { Y2Network::PhysicalInterface.new(nil) }
      let(:wlan0_hwinfo) { double("hwinfo", name: "wlan0") }
      let(:eth0_hwinfo) { double("hwinfo", name: "eth0") }

      before do
        allow(wlan0).to receive(:hardware).and_return(wlan0_hwinfo)
        allow(eth0).to receive(:hardware).and_return(eth0_hwinfo)
      end

      it "returns the interface with the given name" do
        expect(collection.by_name("wlan0")).to be(wlan0)
      end
    end
  end

  describe "#by_type" do
    context "when an InterfaceType instance is given" do
      it "returns a collection containing the interfaces with the given type" do
        by_type = collection.by_type(Y2Network::InterfaceType::WIRELESS)
        expect(by_type.to_a).to eq([wlan0])
        expect(by_type).to be_a(described_class)
      end
    end

    context "when type's shortname is given as string" do
      it "returns a collection containing the interfaces with the given type" do
        by_type = collection.by_type("br")
        expect(by_type.to_a).to eq([br0])
        expect(by_type).to be_a(described_class)
      end
    end

    context "when type's shortname is given as symbol" do
      it "returns a collection containing the interfaces with the given type" do
        by_type = collection.by_type(:eth)
        expect(by_type.to_a).to eq([eth0])
        expect(by_type).to be_a(described_class)
      end
    end
  end

  describe "#push" do
    let(:wlan1) { Y2Network::PhysicalInterface.new("wlan1") }

    it "adds an interface to the list" do
      collection.push(wlan1)
      expect(collection.by_name(wlan1.name)).to eq(wlan1)
    end
  end

  describe "#delete_if" do
    it "deletes elements which meet a condition" do
      expect(collection.by_name("eth0")).to eq(eth0)
      collection.delete_if { |i| i.name == "eth0" }
      expect(collection.by_name("eth0")).to be_nil
    end

    it "returns the collection" do
      same_collection = collection.delete_if { |i| i.name == "eth0" }
      expect(same_collection).to eq(collection)
    end
  end

  describe "#==" do
    context "when the given collection contains the same interfaces" do
      let(:other) { described_class.new([wlan0, br0, eth0]) }

      it "returns true" do
        expect(collection).to eq(other)
      end
    end

    context "when the given collection does not contain the same interfaces" do
      let(:other) { described_class.new([eth0]) }

      it "returns false" do
        expect(collection).to_not eq(other)
      end
    end
  end

  describe "#physical" do
    it "returns only physical interfaces" do
      expect(collection.physical.map(&:name)).to eq(["eth0", "wlan0"])
    end
  end

  describe "#known_names" do
    it "returns the list of known interfaces" do
      expect(collection.known_names).to eq(["eth0", "br0", "wlan0"])
    end

    context "when an interface was renamed" do
      before do
        eth0.rename("eth1", :mac)
      end
      it "returns the old and the new names" do
        expect(collection.known_names).to eq(["eth0", "eth1", "br0", "wlan0"])
      end
    end
  end

  describe "#free_names" do
    it "returns count of names with prefix that is not yet used" do
      expect(collection.free_names("eth", 3)).to eq(["eth1", "eth2", "eth3"])
    end
  end

  describe "#+" do
    let(:interfaces) { [eth0] }
    let(:other) { Y2Network::InterfacesCollection.new([br0]) }

    it "returns a collection containing all the objects" do
      new_collection = collection + other
      expect(new_collection.to_a).to eq([eth0, br0])
    end
  end
end
