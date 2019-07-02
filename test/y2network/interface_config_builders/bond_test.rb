#!/usr/bin/env rspec

require_relative "../../test_helper"

require "yast"
require "y2network/interface_config_builders/bond"

describe Y2Network::InterfaceConfigBuilders::Bond do
  let(:config) { Y2Network::Config.new(source: :test) }

  before do
    allow(Y2Network::Config)
      .to receive(:find)
      .with(:yast)
      .and_return(config)
  end

  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Bond.new
    res.name = "bond0"
    res
  end

  describe "#type" do
    it "returns 'bond'" do
      expect(subject.type).to eq "bond"
    end
  end

  describe "#bondable_interfaces" do
    it "returns array" do
      expect(subject.bondable_interfaces).to be_a(::Array)
    end
  end
end
