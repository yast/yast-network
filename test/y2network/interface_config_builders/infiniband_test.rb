#!/usr/bin/env rspec

require_relative "../../test_helper"

require "yast"
require "y2network/interface_config_builders/infiniband"

describe Y2Network::InterfaceConfigBuilders::Infiniband do
  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Infiniband.new
    res.name = "ib0"
    res
  end

  describe "#type" do
    it "returns infiniband interface type" do
      expect(subject.type).to eq Y2Network::InterfaceType::INFINIBAND
    end
  end

  describe "#save" do
    around do |test|
      Yast::LanItems.AddNew
      test.call
      Yast::LanItems.Rollback
    end

    it "stores ipoib configuration" do
      subject.ipoib_mode = "datagram"

      subject.save
      devmap = subject.device_sysconfig

      expect(devmap).to include("IPOIB_MODE" => "datagram")
    end

    it "stores nil to ipoib configuration if mode is 'default'" do
      subject.ipoib_mode = "default"

      subject.save
      devmap = subject.device_sysconfig

      expect(devmap).to include("IPOIB_MODE" => nil)
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
