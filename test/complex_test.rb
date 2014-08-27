#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast::UIShortcuts
include Yast::I18n

Yast.import "LanItems"

# creating a wrapper for Yast's 'header' file
$LOAD_PATH.unshift File.expand_path('../../src', __FILE__)
require "include/network/lan/complex"

class NetworkLanComplexInclude
  extend Yast::NetworkLanComplexInclude
end

describe "NetworkLanComplexInclude::input_done?" do

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
