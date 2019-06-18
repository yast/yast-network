#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

require "y2network/config"
require "y2network/interface"

Yast.import "LanItems"

describe Yast::LanItems do
  let(:netconfig_items) do
    {
      "eth"  => {
        "eth1" => { "BOOTPROTO" => "none" },
        "eth2" => { "BOOTPROTO" => "none" },
        "eth4" => {
          "BOOTPROTO" => "static",
          "IPADDR"    => "0.0.0.0",
          "PREFIX"    => "32"
        },
        "eth5" => { "BOOTPROTO" => "static", "STARTMODE" => "nfsroot" },
        "eth6" => { "BOOTPROTO" => "static", "STARTMODE" => "ifplugd" }
      },
      "tun"  => {
        "tun0" => {
          "BOOTPROTO" => "static",
          "STARTMODE" => "onboot",
          "TUNNEL"    => "tun"
        }
      },
      "tap"  => {
        "tap0" => {
          "BOOTPROTO" => "static",
          "STARTMODE" => "onboot",
          "TUNNEL"    => "tap"
        }
      },
      "br"   => {
        "br0" => {
          "BOOTPROTO" => "dhcp",
          "BRIDGE"    => "yes"
        }
      },
      "bond" => {
        "bond0" => {
          "BOOTPROTO"      => "static",
          "BONDING_MASTER" => "yes",
          "BONDING_SLAVE0" => "eth1",
          "BONDING_SLAVE1" => "eth2"
        }
      }
    }
  end

  let(:hwinfo_items) do
    [
      { "dev_name" => "eth11" },
      { "dev_name" => "eth12" }
    ]
  end

  let(:expected_bridgeable) do
    [
      "bond0",
      "eth4",
      "eth11",
      "eth12",
      "tap0"
    ]
  end

  before(:each) do
    allow(Yast::NetworkInterfaces).to receive(:Read).and_return(true)
    allow(Yast::NetworkInterfaces).to receive(:FilterDevices).with("netcard") { netconfig_items }
    allow(Yast::NetworkInterfaces).to receive(:adapt_old_config!)
    allow(Yast::NetworkInterfaces).to receive(:CleanHotplugSymlink).and_return(true)

    allow(Yast::LanItems).to receive(:ReadHardware) { hwinfo_items }

    allow(Yast::NetworkInterfaces).to receive(:devmap).and_return(nil)
    allow(Yast::NetworkInterfaces).to receive(:GetType).and_return("eth")

    netconfig_items.each_pair do |type, device_maps|
      device_maps.each_pair do |dev, devmap|
        allow(Yast::NetworkInterfaces)
          .to receive(:devmap)
          .with(dev)
          .and_return(devmap)
        allow(Yast::NetworkInterfaces)
          .to receive(:GetType)
          .with(dev)
          .and_return(type)
      end
    end

    Yast::LanItems.Read
  end

  describe "#GetBridgeableInterfaces" do
    # when converting to new API new API is used
    # for selecting bridgable devices but imports interfaces
    # from LanItems internally
    let(:br0) { instance_double(Y2Network::Interface, name: "br0", type: "br") }
    let(:config) { Y2Network::Config.new(source: :test) }

    it "returns list of slave candidates" do
      expect(config.interfaces.select_bridgeable(br0).map(&:name))
        .to match_array expected_bridgeable
    end
  end
end
