#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

# need a class to stub the sleep call; hard to stub it on Kernel
class LinkHandlersClass
  def initialize
    Yast.include self, "network/routines.rb"
  end
end

describe "phy_connected?" do
  include Yast
  subject { LinkHandlersClass.new }

  before(:each) do
    Yast::SCR.stub(:Execute).with(path(".target.bash"), //) { 0 }
    allow(subject).to receive(:sleep)
  end

  it "returns true if PHY layer is available" do
    Yast::SCR.stub(:Read).with(path(".target.string"), /\/sys\/class\/net/) { 1 }
    expect(subject.phy_connected?("enp0s3")).to eql true
  end

  it "returns false if PHY layer is available" do
    Yast::SCR.stub(:Read).with(path(".target.string"), /\/sys\/class\/net/) { 0 }
    expect(subject.phy_connected?("enp0s3")).to eql false
  end
end
