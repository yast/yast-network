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

require "y2network/ipoib_mode"

describe Y2Network::IpoibMode do
  subject(:mode) { described_class.new("datagram") }

  describe ".all" do
    it "returns all know IPoIB modes" do
      expect(described_class.all).to contain_exactly(
        Y2Network::IpoibMode::CONNECTED,
        Y2Network::IpoibMode::DATAGRAM,
        Y2Network::IpoibMode::DEFAULT
      )
    end
  end

  describe ".from_name" do
    it "returns the IPoIB mode with the given mode" do
      expect(described_class.from_name("datagram")).to eq(Y2Network::IpoibMode::DATAGRAM)
    end
  end

  describe "#==" do
    context "when the other object refers to the same IPoIB mode" do
      it "returns true" do
        expect(mode).to eq(described_class.new("datagram"))
      end
    end

    context "when the other object refers to a different IPoIB mode" do
      it "returns false" do
        expect(mode).to_not eq(described_class.new("connected"))
      end
    end
  end
end
