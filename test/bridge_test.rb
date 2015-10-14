#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"

module Yast
  describe LanItems do
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
          "tun0"  => {
            "BOOTPROTO" => "static",
            "STARTMODE" => "onboot",
            "TUNNEL"    => "tun"
          }
        },
        "tap"  => {
          "tap0"  => {
            "BOOTPROTO" => "static",
            "STARTMODE" => "onboot",
            "TUNNEL"    => "tap"
          }
        },
        "br"   => {
          "br0"   => { "BOOTPROTO" => "dhcp" }
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
      allow(NetworkInterfaces).to receive(:FilterDevices).with("netcard") { netconfig_items }

      allow(LanItems).to receive(:ReadHardware) { hwinfo_items }
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
        ).to match_array expected_bridgeable
      end
    end
  end
end
