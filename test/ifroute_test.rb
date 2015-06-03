#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "NetworkInterfaces"
Yast.import "Routing"

describe "Routing#Read" do
  include Yast

  subject(:network_interfaces) { Yast::NetworkInterfaces }
  subject(:scr) { Yast::SCR }
  subject(:routing) { Yast::Routing }

  ROUTES_FILE = [
    {
      "destination" => "default",
      "device"      => "eth0",
      "gateway"     => "1.1.1.1",
      "netmask"     => "-"
    }
  ]
  IFROUTE_FILE = [
    {
      "destination" => "default",
      "device"      => "-",
      "gateway"     => "1.1.1.1",
      "netmask"     => "-"
    }
  ]

  before(:each) do
    allow(network_interfaces)
      .to receive(:Read)
      .and_return(true)
    allow(network_interfaces)
      .to receive(:List)
      .and_return(["eth0"])
    allow(scr)
      .to receive(:Read)
      .and_return(nil)
  end

  it "loades ifroute-* files" do
    allow(scr)
      .to receive(:Read)
      .with(path(".routes"))
      .and_return([])

    expect(scr)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE)
    expect(Yast::Routing.Read).to be true
    expect(routing.Routes).not_to be_empty
  end

  it "replace implicit device name using explicit one" do
    expect(scr)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE)
    expect(routing.Read).to be true
    # check if implicit device name "-" is rewritten according device name
    # which ifroute belongs to
    expect(routing.Routes.first["device"])
      .to eql "eth0"
  end

  it "removes duplicit routes" do
    expect(scr)
      .to receive(:Read)
      .with(path(".routes"))
      .and_return(ROUTES_FILE)
    expect(scr)
      .to receive(:Read)
      .with(path(".ifroute-eth0"))
      .and_return(IFROUTE_FILE)
    expect(routing.Read).to be true
    expect(routing.Routes.size).to eql 1
  end
end

describe "Routing#write_routes" do
  include Yast

  subject(:scr) { Yast::SCR }
  subject(:routing) { Yast::Routing }

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
  ]

  it "writes device assigned routes into correct ifroute file" do
    allow(scr)
      .to receive(:Read)
      .with(path(".target.size"), Yast::RoutingClass::ROUTES_FILE)
      .and_return(1)
    allow(routing)
      .to receive(:devices)
      .and_return(["eth0", "eth1", "eth2"])
    expect(scr)
      .to receive(:Execute)
      .with(path(".target.bash"), /^\/bin\/cp/)
      .and_return(0)

    expect(scr)
      .to receive(:Write)
      .with(path(".ifroute-eth0"), anything)
      .and_return(true)
    expect(scr)
      .to receive(:Write)
      .with(path(".ifroute-eth1"), anything)
      .and_return(true)
    expect(scr)
      .to receive(:Execute)
      .with(path(".target.remove"), "/etc/sysconfig/network/ifroute-eth2")
      .and_return(true)
    expect(scr)
      .to receive(:Write)
      .with(path(".target.string"), "/etc/sysconfig/network/routes", "")
      .and_return(true)
    expect(routing.write_routes(ROUTES_WITH_DEV)).to be true
  end
end

describe "Routing#Write" do
  include Yast

  subject(:network_interfaces) { Yast::NetworkInterfaces }
  subject(:routing) { Yast::Routing }

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
  ]

  AY_ROUTES.each_with_index do |ay_test, i|
    it "does write route configuration files, ##{i}" do
      # Devices which have already been imported by Lan.Import have to be read.
      # (bnc#900352)
      allow(network_interfaces)
        .to receive(:List)
        .with("")
        .and_return(["eth0"])

      routing.Import(ay_test)

      expect(routing)
        .to receive(:write_route_file)
        .twice
        .with(kind_of(String), ay_test.fetch("routes", []))
        .and_return true

      routing.Write
    end
  end
end
