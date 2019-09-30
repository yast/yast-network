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

describe Y2Network::InterfaceType do
  subject(:ethernet) { described_class.from_short_name("eth") }

  describe ".from_short_name" do
    it "returns the type for a given shortname" do
      type = described_class.from_short_name("wlan")
      expect(type).to be(Y2Network::InterfaceType::WIRELESS)
    end
  end

  describe ".all" do
    it "returns all known interface types" do
      expect(described_class.all).to_not be_empty
      expect(described_class.all.first).to be_a described_class
    end
  end

  describe "#<name>?" do
    it "returns true if name is same as in method name" do
      expect(ethernet.ethernet?).to eq true
      expect(ethernet.wireless?).to eq false
    end
  end

  describe "#<shortname>?" do
    it "returns true if short_name is same as in method name" do
      expect(ethernet.eth?).to eq true
      expect(ethernet.wlan?).to eq false
    end
  end
end
