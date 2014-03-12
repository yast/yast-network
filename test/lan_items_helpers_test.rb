#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "LanItems"

describe "LanItemsClass#IsItemConfigured" do

  it "succeeds when item has configuration" do
    Yast::LanItems.stub(:GetLanItem) { { "ifcfg" => "enp0s3" } }

    expect(Yast::LanItems.IsItemConfigured(0)).to be_true
  end

  it "fails when item doesn't exist" do
    Yast::LanItems.stub(:GetLanItem) { {} }

    expect(Yast::LanItems.IsItemConfigured(0)).to be_false
  end

  it "fails when item's configuration doesn't exist" do
    Yast::LanItems.stub(:GetLanItem) { { "ifcfg" => nil } }

    expect(Yast::LanItems.IsItemConfigured(0)).to be_false
  end
end
