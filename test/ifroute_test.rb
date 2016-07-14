#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "NetworkInterfaces"
Yast.import "Routing"

describe "Yast::Routing#Read" do
  ROUTES_FILE = [
    {
      "destination" => "default",
      "device"      => "eth0",
      "gateway"     => "1.1.1.1",
      "netmask"     => "-"
    }
  ].freeze
  IFROUTE_FILE = [
    {
      "destination" => "default",
      "device"      => "-",
      "gateway"     => "1.1.1.1",
      "netmask"     => "-"
    }
  ].freeze

  before(:each) do
    allow(Yast::NetworkInterfaces)
      .to receive(:Read)
      .and_return(true)
    allow(Yast::NetworkInterfaces)
      .to receive(:List)
      .and_return(["eth0"])
    allow(Yast::SCR)
      .to receive(:Read)
      .and_return(nil)
  end

  it "loades ifroute-* files" do
    allow(Yast::SCR)
      .to receive(:Read)
      .with(path(".routes"))
      .and_return([])

    expect(Yast::SCR)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE.dup)
    expect(Yast::Routing.Read).to be true
    expect(Yast::Routing.Routes).not_to be_empty
  end

  it "replace implicit device name using explicit one" do
    expect(Yast::SCR)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE.dup)
    expect(Yast::Routing.Read).to be true
    # check if implicit device name "-" is rewritten according device name
    # which ifroute belongs to
    expect(Yast::Routing.Routes.first["device"])
      .to eql "eth0"
  end

  it "removes duplicit routes" do
    expect(Yast::SCR)
      .to receive(:Read)
      .with(path(".routes"))
      .and_return(ROUTES_FILE.dup)
    expect(Yast::SCR)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE.dup)
    expect(Yast::Routing.Read).to be true
    expect(Yast::Routing.Routes.size).to eql 1
  end
end

describe "Yast::Routing#write_routes" do
  ROUTES_WITH_DEV = [
    {
      "destination" => "default",
      "device"      => "eth0",
      "gateway"     => "1.1.1.1",
      "netmask"     => "-"
    },
    {
      "destination" => "default",
      "device"      => "eth1",
      "gateway"     => "2.2.2.2",
      "netmask"     => "-"
    }
  ].freeze

  it "writes device assigned routes into correct ifroute file" do
    allow(Yast::FileUtils)
      .to receive(:Exists)
      .and_return(true)
    allow(Yast::Routing)
      .to receive(:devices)
      .and_return(["eth0", "eth1", "eth2"])
    expect(Yast::SCR)
      .to receive(:Execute)
      .with(path(".target.bash"), /^\/bin\/cp/)
      .and_return(0)

    expect(Yast::SCR)
      .to receive(:Write)
      .with(path(".ifroute-eth0"), anything)
      .and_return(true)
    expect(Yast::SCR)
      .to receive(:Write)
      .with(path(".ifroute-eth1"), anything)
      .and_return(true)
    expect(Yast::SCR)
      .to receive(:Execute)
      .with(path(".target.remove"), "/etc/sysconfig/network/ifroute-eth2")
      .and_return(true)
    expect(Yast::SCR)
      .to receive(:Write)
      .with(path(".target.string"), "/etc/sysconfig/network/routes", "")
      .and_return(true)
    expect(Yast::Routing.write_routes(ROUTES_WITH_DEV)).to be true
  end
end

describe "Yast::Routing#Write" do
  AY_ROUTES = [
    # empty AY config
    {},
    # some routes
    {
      "routes" => [
        {
          "destination" => "192.168.1.0",
          "device"      => "eth0",
          "gateway"     => "10.1.188.1",
          "netmask"     => "255.255.255.0"
        },
        {
          "destination" => "10.1.230.0",
          "device"      => "eth0",
          "gateway"     => "10.1.18.254",
          "netmask"     => "255.255.255.0"
        },
        {
          "destination" => "default",
          "device"      => "eth0",
          "gateway"     => "172.24.88.1",
          "netmask"     => "-"
        }
      ]
    }
  ].freeze

  AY_ROUTES.each_with_index do |ay_test, i|
    it "does write route configuration files, ##{i}" do
      # Devices which have already been imported by Lan.Import have to be read.
      # (bnc#900352)
      allow(Yast::NetworkInterfaces)
        .to receive(:List)
        .with("")
        .and_return(["eth0"])

      Yast::Routing.Import(ay_test)

      expect(Yast::Routing)
        .to receive(:write_route_file)
        .twice
        .with(kind_of(String), ay_test.fetch("routes", []))
        .and_return true

      Yast::Routing.Write
    end
  end
end
