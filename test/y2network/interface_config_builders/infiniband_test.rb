#!/usr/bin/env rspec

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

require_relative "../../test_helper"

require "yast"
require "y2network/interface_config_builders/infiniband"
require "y2network/interfaces_collection"
require "y2network/physical_interface"

describe Y2Network::InterfaceConfigBuilders::Infiniband do
  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Infiniband.new
    res.name = "ib0"
    res
  end

  let(:config) { Y2Network::Config.new(interfaces: interfaces, source: :sysconfig) }
  let(:interfaces) { Y2Network::InterfacesCollection.new([ib0]) }
  let(:ib0) { Y2Network::PhysicalInterface.new("ib0") }

  before do
    allow(Yast::Lan).to receive(:yast_config).and_return(config)
  end

  describe "#type" do
    it "returns infiniband interface type" do
      expect(subject.type).to eq Y2Network::InterfaceType::INFINIBAND
    end
  end

  describe "#ipoib_mode" do
    context "modified by ipoib=" do
      it "returns modified value" do
        subject.ipoib_mode = "default"
        expect(subject.ipoib_mode).to eq "default"
      end
    end
  end
end
