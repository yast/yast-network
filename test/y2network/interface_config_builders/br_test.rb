#!/usr/bin/env rspec

require_relative "../../test_helper"

require "yast"
require "y2network/interface_config_builders/br"

describe Y2Network::InterfaceConfigBuilders::Br do
  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Br.new
    res.name = "br0"
    res
  end

  describe "#type" do
    it "returns 'br'" do
      expect(subject.type).to eq "br"
    end
  end

  describe "#bridgable_interfaces" do
    # TODO: better and more reasonable test when we have easy way how to describe configuration
    it "returns array" do
      expect(subject.bridgable_interfaces).to be_a(::Array)
    end
  end

  describe "#already_configured?" do
    it "returns boolean" do
      expect(subject.already_configured?([])).to eq false
    end
  end
end
