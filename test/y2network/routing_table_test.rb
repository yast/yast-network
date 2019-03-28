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
require "y2network/routing_table"
require "y2network/route"

describe Y2Network::RoutingTable do
  subject(:table) { described_class.new([route]) }

  let(:route) { Y2Network::Route.new(to: :any) }

  describe "#==" do
    let(:other) { Y2Network::RoutingTable.new([other_route])}

    context "given two routing tables containing the same set of routes" do
      let(:other_route) { Y2Network::Route.new(to: :any) }

      it "returns true" do
        expect(table).to eq(other)
      end
    end

    context "given two routing tables with different set of routes" do
      let(:other_route) { Y2Network::Route.new(to: IPAddr.new("10.0.0.0/8")) }

      it "returns false" do
        expect(table).to_not eq(other)
      end
    end
  end
end
