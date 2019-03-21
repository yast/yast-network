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
require "y2network/config"
require "y2network/routing_table"
require "y2network/interface"
require "y2network/config_writer/sysconfig"

describe Y2Network::Config do
  subject(:config) do
    described_class.new(interfaces: [eth0], routing_tables: routing_tables, source: :sysconfig)
  end

  let(:route1) { double("Y2Network::Route") }
  let(:route2) { double("Y2Network::Route") }

  let(:table1) { Y2Network::RoutingTable.new([route1]) }
  let(:table2) { Y2Network::RoutingTable.new([route2]) }

  let(:eth0) { Y2Network::Interface.new("eth0") }

  let(:routing_tables) { [table1, table2] }

  describe "#routes" do
    it "returns routes from all tables" do
      expect(config.routes).to eq([route1, route2])
    end
  end

  describe "#write" do
    let(:writer) { instance_double(Y2Network::ConfigWriter::Sysconfig) }

    before do
      allow(Y2Network::ConfigWriter).to receive(:for).with(:sysconfig)
        .and_return(writer)
    end

    it "writes the config using the required writer" do
      expect(writer).to receive(:write).with(config)
      config.write
    end
  end
end
