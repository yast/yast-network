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
require "y2network/interface_config_builders/bridge"

describe Y2Network::InterfaceConfigBuilders::Bridge do
  let(:config) { Y2Network::Config.new(source: :test) }

  before do
    allow(Y2Network::Config)
      .to receive(:find)
      .with(:yast)
      .and_return(config)
  end

  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Bridge.new
    res.name = "br0"
    res
  end

  describe "#type" do
    it "returns bridge type" do
      expect(subject.type).to eq Y2Network::InterfaceType::BRIDGE
    end
  end

  describe "#bridgable_interfaces" do
    # TODO: better and more reasonable test when we have easy way how to describe configuration
    it "returns array" do
      expect(subject.bridgeable_interfaces).to be_a(::Array)
    end
  end

  describe "#require_adaptation?" do
    it "returns boolean" do
      expect(subject.require_adaptation?([])).to eq false
    end
  end
end
