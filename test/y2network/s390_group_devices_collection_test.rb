# Copyright (c) [2020] SUSE LLC
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
require "y2network/s390_group_devices_collection"

describe Y2Network::S390GroupDevicesCollection do
  subject(:collection) { described_class.new(devices) }

  let(:qeth_0700) { Y2Network::S390GroupDevice.new("qeth", "0.0.0700:0.0.0701:0.0.0702") }
  let(:qeth_0800) do
    Y2Network::S390GroupDevice.new("qeth", "0.0.0800:0.0.0801:0.0.0802", true, "eth0")
  end
  let(:devices) { [qeth_0700, qeth_0800] }

  describe "#by_id" do
    it "returns the s390 group device with the given id" do
      expect(collection.by_id("0.0.0700:0.0.0701:0.0.0702")).to eq(qeth_0700)
    end
  end

  describe "#by_type" do
    it "returns a collection with all the devices with the given type" do
      expect(collection.by_type("qeth")).to eq(collection)
    end
  end

  describe "#delete_if" do
    it "deletes elements which meet a condition" do
      expect(collection.by_id(qeth_0700.id)).to eq(qeth_0700)
      collection.delete_if { |i| i.id == qeth_0700.id }
      expect(collection.by_id(qeth_0700.id)).to be_nil
    end

    it "returns the collection" do
      same_collection = collection.delete_if { |i| i.id == qeth_0700 }
      expect(same_collection).to eq(collection)
    end
  end

  describe "#==" do
    context "when the given collection contains the same interfaces" do
      let(:other) { described_class.new([qeth_0700, qeth_0800]) }

      it "returns true" do
        expect(collection).to eq(other)
      end
    end

    context "when the given collection does not contain the same interfaces" do
      let(:other) { described_class.new([qeth_0700]) }

      it "returns false" do
        expect(collection).to_not eq(other)
      end
    end
  end

  describe "#push" do
    let(:ctc_c000) { Y2Network::S390GroupDevice.new("ctc", "0.0.c000:0.0.c001") }

    it "adds an interface to the list" do
      collection.push(ctc_c000)
      expect(collection.by_id(ctc_c000.id)).to eq(ctc_c000)
    end
  end
end
