#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"
Yast.import "Stage"

class NetworkLanComplexIncludeClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/complex.rb"
  end
end

describe "NetworkLanComplexInclude::input_done?" do
  subject { NetworkLanComplexIncludeClass.new }

  BOOLEAN_PLACEHOLDER = "placeholder (true or false)"

  context "when not running in installer" do
    before(:each) do
      allow(Yast::Stage)
        .to receive(:initial)
        .and_return(false)
    end

    it "returns true for input different than :abort" do
      expect(subject.input_done?(:no_abort)).to eql true
    end

    it "returns true for input equal to :abort in case of no user modifications" do
      allow(Yast::LanItems)
        .to receive(:GetModified)
        .and_return(false)

      expect(subject.input_done?(:abort)).to eql true
    end

    it "asks user for abort confirmation for input equal to :abort and user did modifications" do
      allow(Yast::LanItems)
        .to receive(:GetModified)
        .and_return(true)

      expect(subject)
        .to receive(:ReallyAbort)
        .and_return(BOOLEAN_PLACEHOLDER)

      expect(subject.input_done?(:abort)).to eql BOOLEAN_PLACEHOLDER
    end
  end

  context "when running in installer" do
    before(:each) do
      allow(Yast::Stage)
        .to receive(:initial)
        .and_return(true)
    end

    it "asks user for installation abort confirmation for input equal to :abort" do
      expect(Yast::Popup)
        .to receive(:ConfirmAbort)
        .and_return(BOOLEAN_PLACEHOLDER)

      expect(subject.input_done?(:abort)).to eql BOOLEAN_PLACEHOLDER
    end
  end
end
