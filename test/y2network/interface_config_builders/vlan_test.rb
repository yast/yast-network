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
require "y2network/interface_config_builders/vlan"
require "y2network/interface_type"

describe Y2Network::InterfaceConfigBuilders::Vlan do
  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Vlan.new
    res.name = "vlan0"
    res
  end

  before do
    allow(config_builder).to receive(:yast_config).and_return(Y2Network::Config.new(source: :testing))
  end

  describe "#type" do
    it "returns vlan type" do
      expect(subject.type).to eq Y2Network::InterfaceType::VLAN
    end
  end

  describe "#possible_vlans" do
    it "returns hash" do
      expect(subject.possible_vlans).to be_a(Hash)
    end
  end
end
