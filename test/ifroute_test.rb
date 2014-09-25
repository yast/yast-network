#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast

Yast.import "NetworkInterfaces"
Yast.import "Routing"

describe "Routing#Read" do
  ROUTES_FILE = [
    {
      "destination"=>"default",
      "device"=>"eth0",
      "gateway"=>"1.1.1.1",
      "netmask"=>"-"
    }
  ]
  IFROUTE_FILE = [
    {
      "destination"=>"default",
      "device"=>"-",
      "gateway"=>"1.1.1.1",
      "netmask"=>"-"
    }
  ]

  before(:each) do
    allow(NetworkInterfaces)
      .to receive(:Read)
      .and_return(true)
    allow(NetworkInterfaces)
      .to receive(:List)
      .and_return(["eth0"])
    allow(SCR)
      .to receive(:Read)
      .and_return(nil)
  end

  it "loades ifroute-* files" do
    allow(SCR)
      .to receive(:Read)
      .with(path(".routes"))
      .and_return([])

    expect(SCR)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE)
    expect(Routing.Read).to be true
    expect(Routing.Routes).not_to be_empty
  end

  it "replace implicit device name using explicit one" do
    expect(SCR)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE)
    expect(Routing.Read).to be true
    expect(Routing.Routes.first["device"])
      .to eql "eth0"
  end

  it "removes duplicit routes" do
    expect(SCR)
      .to receive(:Read)
      .with(path(".routes"))
      .and_return(ROUTES_FILE)
    expect(SCR)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE)
    expect(Routing.Read).to be true
    expect(Routing.Routes.size).to eql 1
  end

end
