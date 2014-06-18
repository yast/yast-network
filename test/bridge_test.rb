#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

include Yast

Yast.import "LanItems"

module Yast
  describe LanItems do

    NETCONFIG_ITEMS = {
      "eth" => {
        "eth1"  => { "BOOTPROTO" => "none" },
        "eth2"  => { "BOOTPROTO" => "none" },
        "eth4"  => {
          "BOOTPROTO" => "static",
          "IPADDR"    => "0.0.0.0",
          "PREFIX"    => "32"
        },
        "eth5"  => { "BOOTPROTO" => "static", "STARTMODE" => "nfsroot" },
        "eth6"  => { "BOOTPROTO" => "static", "STARTMODE" => "ifplugd" },
      },
      "tun" => {
        "tun0"  => {
          "BOOTPROTO" => "static",
          "STARTMODE" => "onboot",
          "TUNNEL"    => "tun"
        },
      },
      "tap" => {
        "tap0"  => {
          "BOOTPROTO" => "static",
          "STARTMODE" => "onboot",
          "TUNNEL"    => "tap"
        },
      },
      "br" => {
        "br0"   => { "BOOTPROTO" => "dhcp" },
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

    HWINFO_ITEMS = [
      { "dev_name" => "eth11" },
      { "dev_name" => "eth12" }
    ]

    EXPECTED_BRIDGEABLE = [
      "bond0",
      "eth4",
      "eth11",
      "eth12",
      "tap0"
    ]

    before(:each) do
      NetworkInterfaces.stub(:FilterDevices).with("netcard") { NETCONFIG_ITEMS }

      LanItems.stub(:ReadHardware) { HWINFO_ITEMS }
      LanItems.Read
    end

    describe "#GetBridgeableInterfaces" do

      before(:each) do
        # FindAndSelect initializes internal state of LanItems it
        # is used internally by some helpers
        LanItems.FindAndSelect("br0")
      end

      it "returns list of slave candidates" do
        expect(
          LanItems
            .GetBridgeableInterfaces(LanItems.GetCurrentName)
            .map { |i| LanItems.GetDeviceName(i) }
        ).to match_array EXPECTED_BRIDGEABLE
      end
    end
  end
end
