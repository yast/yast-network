#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

# creating a wrapper for Yast's 'header' file
$LOAD_PATH.unshift File.expand_path("../../src", __FILE__)
require "include/network/lan/s390"

class NetworkLanS390IncludeTestClient < Yast::Client
  include Singleton

  def initialize
    Yast.include self, "network/lan/s390.rb"
  end
end

Yast.import "Arch"
Yast.import "FileUtils"

describe "NetworkLanS390Include::s390_DriverLoaded" do
  subject { NetworkLanS390IncludeTestClient.instance }
  DEVNAME = "devname"

  before(:each) do
    allow(Yast::Arch)
      .to receive(:s390)
      .and_return(true)
  end

  # it checks if a driver which emulates common linux device
  # on top of s390 one is loaded already
  it "succeeds when driver is already loaded" do
    expect(Yast::FileUtils)
      .to receive(:IsDirectory)
      .with("#{Yast::NetworkLanS390Include::SYS_DIR}/#{DEVNAME}")
      .and_return(true)

    expect(subject.s390_DriverLoaded(DEVNAME)).to be true
  end

  it "fails when driver is not loaded" do
    expect(Yast::FileUtils)
      .to receive(:IsDirectory)
      .with("#{Yast::NetworkLanS390Include::SYS_DIR}/#{DEVNAME}")
      .and_return(false)

    expect(subject.s390_DriverLoaded(DEVNAME)).to be false
  end
end
