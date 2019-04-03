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
require "y2network/route"
require "y2network/interface"
require "ipaddr"

describe Y2Network::Route do
  subject(:route) do
    described_class.new(to: to, interface: interface)
  end

  let(:to) { IPAddr.new("192.168.122.0/24") }
  let(:interface) { Y2Network::Interface.new("eth0") }

  describe "#default?" do
    context "when it is the default route" do
      let(:to) { :default }

      it "returns true" do
        expect(route.default?).to eq(true)
      end
    end

    context "when it is not the default route" do
      it "returns false" do
        expect(route.default?).to eq(false)
      end
    end
  end

  describe "==" do
    let(:other_to) { IPAddr.new("192.168.122.0/24") }
    let(:other_interface) { Y2Network::Interface.new("eth0") }
    let(:other_gateway) { nil }
    let(:other_options) { "" }

    let(:other) do
      described_class.new(
        to: other_to, interface: other_interface, gateway: other_gateway, options: other_options
      )
    end

    context "given two routes with the same data" do
      it "returns true" do
        expect(route).to eq(other)
      end
    end

    context "when the destination is different" do
      let(:other_to) { IPAddr.new("10.0.0.0") }

      it "returns false" do
        expect(route).to_not eq(other)
      end
    end

    context "when the interface is different" do
      let(:other_interface) { Y2Network::Interface.new("eth1") }

      it "returns false" do
        expect(route).to_not eq(other)
      end
    end

    context "when the gateway is different" do
      let(:other_gateway) { IPAddr.new("192.168.122.1") }

      it "returns false" do
        expect(route).to_not eq(other)
      end
    end

    context "when the options are different" do
      let(:other_options) { "some options" }

      it "returns false" do
        expect(route).to_not eq(other)
      end
    end
  end
end
