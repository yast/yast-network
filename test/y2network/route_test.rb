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
    described_class.new(to, interface)
  end

  let(:to) { IPAddr.new("192.168.122.1") }
  let(:interface) { Y2Network::Interface.new("eth0") }

  describe "#default?" do
    context "when it is the default route" do
      let(:to) { nil }

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
end
