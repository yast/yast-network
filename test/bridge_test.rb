#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

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
        "br0" => { "BOOTPROTO" => "dhcp" }
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

    netconfig_items.each_pair do |_type, device_maps|
      device_maps.each_pair do |dev, devmap|
        allow(Yast::NetworkInterfaces)
          .to receive(:devmap)
          .with(dev)
          .and_return(devmap)
      end
    end

    Yast::LanItems.Read
  end

  describe "#GetBridgeableInterfaces" do
    before(:each) do
      # FindAndSelect initializes internal state of LanItems it
      # is used internally by some helpers
      Yast::LanItems.FindAndSelect("br0")
    end

    it "returns list of slave candidates" do
      expect(
        Yast::LanItems
          .GetBridgeableInterfaces(Yast::LanItems.GetCurrentName)
          .map { |i| Yast::LanItems.GetDeviceName(i) }
      ).to match_array expected_bridgeable
    end
  end
end
