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
require "y2network/interface"

describe Y2Network::Interface do
  subject(:interface) do
    described_class.new("eth0")
  end

  describe ".from_connection" do
    context "when the connection is virtual" do
      let(:conn) do
        Y2Network::ConnectionConfig::Bridge.new.tap { |c| c.name = "br0" }
      end

      it "returns a virtual interface" do
        interface = described_class.from_connection(conn)
        expect(interface).to be_a(Y2Network::VirtualInterface)
      end
    end

    context "when the connection is not virtual" do
      let(:conn) do
        Y2Network::ConnectionConfig::Wireless.new.tap { |c| c.name = "wlan0" }
      end

      it "returns a physical interface" do
        interface = described_class.from_connection(conn)
        expect(interface).to be_a(Y2Network::PhysicalInterface)
      end
    end
  end

  describe "#==" do
    context "given two interfaces with the same name" do
      let(:other) { Y2Network::Interface.new(interface.name) }

      it "returns true" do
        expect(interface).to eq(other)
      end
    end

    context "given two interfaces with a different name" do
      let(:other) { Y2Network::Interface.new("eth1") }

      it "returns false" do
        expect(interface).to_not eq(other)
      end
    end
  end

  describe "#modules_names" do
    let(:driver) { instance_double(Y2Network::Driver) }
    let(:hwinfo) { instance_double(Y2Network::Hwinfo, drivers: [driver]) }

    before do
      allow(interface).to receive(:hardware).and_return(hwinfo)
    end

    it "returns modules names from hardware information" do
      expect(interface.drivers).to eq([driver])
    end
  end
end
