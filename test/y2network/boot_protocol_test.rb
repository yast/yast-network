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

require "y2network/boot_protocol"

describe Y2Network::BootProtocol do
  subject { described_class.new("dhcp") }

  describe ".all" do
    it "returns all known boot protocols" do
      expect(described_class.all).to_not be_empty
      expect(described_class.all.first).to be_a(described_class)
    end
  end

  describe ".from_name" do
    it "returns boot protocol with given name" do
      expect(described_class.from_name("dhcp4")).to eq Y2Network::BootProtocol::DHCP4
    end

    it "returns nil if given name not found" do
      expect(described_class.from_name("dhcp8")).to eq nil
    end
  end

  describe "#dhcp?" do
    it "returns true if protocol at least partially is read from dhcp" do
      expect(Y2Network::BootProtocol::DHCP4.dhcp?).to eq true
      expect(Y2Network::BootProtocol::DHCP_AUTOIP.dhcp?).to eq true
      expect(Y2Network::BootProtocol::STATIC.dhcp?).to eq false
    end
  end
end
