#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast::UIShortcuts
include Yast::I18n

Yast.import "LanItems"
Yast.import "Stage"

# creating a wrapper for Yast's 'header' file
$LOAD_PATH.unshift File.expand_path('../../src', __FILE__)
require "include/network/lan/complex"

class NetworkLanComplexInclude
  extend Yast::NetworkLanComplexInclude
end

describe "NetworkLanComplexInclude::input_done?" do

  context "when not running in installer" do

    before(:each) do
      allow(Yast::Stage)
        .to receive(:initial)
        .and_return(false)
    end

    it "returns true for input different than :abort" do
      expect(NetworkLanComplexInclude.input_done?(:no_abort)).to eql true
    end

    it "returns true for input equal to :abort in case of no user modifications" do
      allow(Yast::LanItems)
        .to receive(:modified)
        .and_return(false)

      expect(NetworkLanComplexInclude.input_done?(:abort)).to eql true
    end

    it "asks user for abort confirmation for input equal to :abort and user did modifications" do
      allow(Yast::LanItems)
        .to receive(:modified)
        .and_return(true)

      expect(NetworkLanComplexInclude)
        .to receive(:ReallyAbort)

      NetworkLanComplexInclude.input_done?(:abort)
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

      NetworkLanComplexInclude.input_done?(:abort)
    end
  end
end
