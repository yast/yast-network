#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "LanItems"

describe "LanItems#GetDeviceMap" do

  it "returns non nil value when item is not configured" do
    Yast::LanItems.stub(:IsItemConfigured) { false }

    ret = Yast::LanItems.GetDeviceMap(0)

    expect(ret).not_to be_nil
    expect(ret).to be_instance_of(Hash)
  end
end
