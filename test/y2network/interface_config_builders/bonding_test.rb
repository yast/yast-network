#!/usr/bin/env rspec

require_relative "../../test_helper"

require "yast"
require "y2network/interface_config_builders/bonding"

describe Y2Network::InterfaceConfigBuilders::Bonding do
  let(:config) { Y2Network::Config.new(source: :test) }

  before do
    allow(Y2Network::Config)
      .to receive(:find)
      .with(:yast)
      .and_return(config)
  end

  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Bonding.new
    res.name = "bond0"
    res
  end

  describe "#type" do
    it "returns bonding interface type" do
      expect(subject.type).to eq Y2Network::InterfaceType::BONDING
    end
  end

  describe "#bondable_interfaces" do
    it "returns array" do
      expect(subject.bondable_interfaces).to be_a(::Array)
    end
  end
end
