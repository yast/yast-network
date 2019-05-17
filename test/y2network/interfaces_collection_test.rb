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

describe Y2Network::InterfacesCollection do
  subject(:collection) { described_class.new(interfaces) }

  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:wlan0) { Y2Network::Interface.new("wlan0") }
  let(:interfaces) { [eth0, wlan0] }

  describe "#by_name" do
    it "returns the interface with the given name" do
      expect(collection.by_name("eth0")).to eq(eth0)
    end
  end

  describe "#push" do
    let(:wlan1) { Y2Network::Interface.new("wlan1") }

    it "adds an interface to the list" do
      collection.push(wlan1)
      expect(collection.by_name(wlan1.name)).to eq(wlan1)
    end
  end

  describe "#==" do
    context "when the given collection contains the same interfaces" do
      let(:other) { described_class.new([wlan0, eth0]) }

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
end
