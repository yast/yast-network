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
require "y2network/routing_config"

describe Y2Network::RoutingConfig do
  subject(:config) do
    described_class.new(
      tables: tables
    )
  end

  let(:route1) { double("Y2Network::Route") }
  let(:route2) { double("Y2Network::Route") }

  let(:table1) { Y2Network::RoutingTable.new([route1]) }
  let(:table2) { Y2Network::RoutingTable.new([route2]) }

  let(:tables) { [table1, table2] }

  describe "#forward_v4"

  describe "#forward_v6"

  describe "#routes" do
    it "returns routes from all tables" do
      expect(config.routes).to eq([route1, route2])
    end
  end
end
