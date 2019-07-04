#!/usr/bin/env rspec

require_relative "../../test_helper"

require "yast"
require "y2network/interface_config_builders/ib"

describe Y2Network::InterfaceConfigBuilders::Ib do
  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Ib.new
    res.name = "ib0"
    res
  end

  describe "#type" do
    it "returns 'ib'" do
      expect(subject.type).to eq "ib"
    end
  end

  describe "#save" do
    around do |block|
      Yast::LanItems.AddNew
      block.call
      Yast::LanItems.Rollback
    end

    it "stores ipoib configuration" do
      subject.ipoib_mode = "datagram"
      expect(subject.save).to eq "datagram"
    end

    it "stores nil to ipoib configuration if mode is 'default'" do
      subject.ipoib_mode = "default"
      expect(subject.save).to eq nil
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
