#!/usr/bin/env rspec

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
