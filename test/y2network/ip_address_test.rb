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
require "y2network/ip_address"

describe Y2Network::IPAddress do
  describe ".from_string" do
    context "when a string representing an IPv4 is given" do
      let(:ip_address) { "192.168.122.1/24" }

      it "creates an IPAddress object" do
        ip = described_class.from_string(ip_address)
        expect(ip.address).to eq(IPAddr.new("192.168.122.1"))
        expect(ip.prefix).to eq(24)
      end

      context "when no prefix is given" do
        let(:ip_address) { "192.168.122.1" }

        it "sets a 32 bits prefix" do
          ip = described_class.from_string(ip_address)
          expect(ip.address).to eq(IPAddr.new("192.168.122.1"))
          expect(ip.prefix).to eq(32)
        end
      end
    end

    context "when a string representing an IPv6 is given" do
      let(:ip_address) { "2001:db8:1234:ffff:ffff:ffff:ffff:fff1/48" }

      it "creates an IPAddress object" do
        ip = described_class.from_string(ip_address)
        expect(ip.address).to eq(IPAddr.new("2001:db8:1234:ffff:ffff:ffff:ffff:fff1"))
        expect(ip.prefix).to eq(48)
      end

      context "when no prefix is given" do
        let(:ip_address) { "2001:db8:1234:ffff:ffff:ffff:ffff:fff1" }

        it "sets a 128 bits prefix" do
          ip = described_class.from_string(ip_address)
          expect(ip.address).to eq(IPAddr.new(ip_address))
          expect(ip.prefix).to eq(128)
        end
      end
    end
  end
end
