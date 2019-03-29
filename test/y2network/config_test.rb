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
require "y2network/config_reader/sysconfig"
require "y2network/config_writer/sysconfig"

describe Y2Network::Config do
  subject(:config) do
    described_class.new(interfaces: [eth0], routing: routing, source: :sysconfig)
  end

  let(:route1) { Y2Network::Route.new }
  let(:route2) { Y2Network::Route.new }

  let(:table1) { Y2Network::RoutingTable.new([route1]) }
  let(:table2) { Y2Network::RoutingTable.new([route2]) }

  let(:eth0) { Y2Network::Interface.new("eth0") }

  let(:routing) { Y2Network::Routing.new(tables: [table1, table2]) }

  describe ".from" do
    let(:reader) do
      instance_double(Y2Network::ConfigReader::Sysconfig, config: config)
    end

    before do
      allow(Y2Network::ConfigReader).to receive(:for).with(:sysconfig)
        .and_return(reader)
    end

    it "returns the configuration from the given reader" do
      expect(described_class.from(:sysconfig)).to eq(config)
    end
  end

  describe "#routes" do
    it "returns routes from all tables" do
      expect(config.routing.routes).to eq([route1, route2])
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

  describe "#copy" do
    it "returns a copy of the object" do
      copy = config.copy
      expect(copy).to_not be(config)
      expect(copy.routing.tables.size).to eq(2)
    end

    it "returns a copy whose changes won't affect to the original object" do
      copy = config.copy
      copy.routing.tables.clear
      expect(copy.routing.tables).to be_empty
      expect(config.routing.tables.size).to eq(2)
    end
  end

  describe "#==" do
    let(:copy) { config.copy }

    context "when both configuration contains the same information" do
      it "returns true" do
        expect(copy).to eq(config)
      end
    end

    context "when interfaces list is different" do
      it "returns false" do
        copy.interfaces = [Y2Network::Interface.new("eth1")]
        expect(copy).to_not eq(config)
      end
    end

    context "when routing information is differt" do
      it "returns false" do
        copy.routing.forward_ipv4 = !config.routing.forward_ipv4
        expect(copy).to_not eq(config)
      end
    end
  end
end
