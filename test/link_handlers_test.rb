#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

describe "phy_connected?" do
  before(:each) do
    Yast.include self, "network/routines.rb"

    Yast::SCR.stub(:Execute).with(path(".target.bash"), //) { 0 }
  end

  it "returns true if PHY layer is available" do
    Yast::SCR.stub(:Read).with(path(".target.string"), /\/sys\/class\/net/) { 1 }
    expect(phy_connected?("enp0s3")).to eql true
  end

  it "returns false if PHY layer is available" do
    Yast::SCR.stub(:Read).with(path(".target.string"), /\/sys\/class\/net/) { 0 }
    expect(phy_connected?("enp0s3")).to eql false
  end
end
