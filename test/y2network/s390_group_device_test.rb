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
require "y2network/s390_group_device"

describe Y2Network::S390GroupDevice do
  let(:qeth_0700_id) { "0.0.0700:0.0.0701:0.0.0702" }
  let(:qeth_0800_id) { "0.0.0800:0.0.0801:0.0.0802" }
  let(:ctc_c000_id) { "0.0.c000:0.0.c001" }
  let(:qeth_0700) { described_class.new("qeth", qeth_0700_id) }
  let(:qeth_0800) { described_class.new("qeth", qeth_0800_id, true, "eth0") }
  let(:ctc0) { described_class.new("ctc", ctc_c000_id) }
  subject(:device) { qeth_0700 }

  let(:executor) { double("Yast::Execute", locally!: "") }
  before do
    allow(Yast::Execute).to receive(:stdout).and_return(executor)
  end

  describe "#offline?" do
    context "when the s390 group device is offline" do
      it "returns true" do
        expect(device.offline?).to eq(true)
      end
    end

    context "when the s390 group device is online" do
      it "returns false" do
        expect(qeth_0800.offline?).to eq(false)
      end
    end
  end

  describe "#==" do
    context "given a s390 group device with the same id" do
      it "returns true" do
        expect(device).to eq(qeth_0700)
      end
    end

    context "given a s390 group device with a different id" do
      it "returns false" do
        expect(device).to_not eq(qeth_0800)
      end
    end
  end

  describe ".list" do
    let(:qeth_0700_lszdev) { "#{qeth_0700_id}  \n" }
    let(:qeth_0800_lszdev) { "#{qeth_0800_id}  eth0\n" }
    let(:lszdev_output) { qeth_0700_lszdev + qeth_0800_lszdev }
    before do
      allow(executor).to receive(:locally!).and_return(lszdev_output)
    end

    it "returns an array with the existent s390 group devices of the given type" do
      expect(described_class.list("qeth")).to eq([device, qeth_0800])
    end

    context "when no interface of the given type is listed" do
      let(:lszdev_output) { "" }
      it "returns an empty array" do
        expect(described_class.list("lcs")).to eq([])
      end
    end
  end

  describe ".all" do
    let(:qeth_devices) { [qeth_0700, qeth_0800] }
    let(:ctc_devices) { [ctc0] }
    let(:lcs_devices) { [] }

    before do
      allow(described_class).to receive(:list).with("qeth", false).and_return(qeth_devices)
      allow(described_class).to receive(:list).with("ctc", false).and_return(ctc_devices)
      allow(described_class).to receive(:list).with("lcs", false).and_return([])
    end

    it "returns an array with all the supported s390 group devices" do
      expect(described_class.all).to eq(qeth_devices + ctc_devices)
    end
  end
end
