#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "LanItems"

describe "LanItemsClass#IsItemConfigured" do

  it "succeeds when item has configuration" do
    Yast::LanItems.stub(:GetLanItem) { { "ifcfg" => "enp0s3" } }

    expect(Yast::LanItems.IsItemConfigured(0)).to be_true
  end

  it "fails when item doesn't exist" do
    Yast::LanItems.stub(:GetLanItem) { {} }

    expect(Yast::LanItems.IsItemConfigured(0)).to be_false
  end

  it "fails when item's configuration doesn't exist" do
    Yast::LanItems.stub(:GetLanItem) { { "ifcfg" => nil } }

    expect(Yast::LanItems.IsItemConfigured(0)).to be_false
  end
end

describe "LanItemsClass#delete_dev" do

  MOCKED_ITEMS = {
    0 => {
      "ifcfg" => "enp0s3"
    }
  }

  before(:each) do
    Yast::LanItems.Items = MOCKED_ITEMS
  end

  it "removes device config when found" do
    Yast::LanItems.delete_dev("enp0s3")
    expect(Yast::LanItems.Items).to be_empty
  end
end

describe "LanItemsClass#getNetworkInterfaces" do

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

    EXPECTED_INTERFACES = [
      "eth1",
      "eth2",
      "eth4",
      "eth5",
      "eth6",
      "tun0",
      "tap0",
      "br0",
      "bond0"
    ]

    it "returns list of known interfaces" do
      Yast::NetworkInterfaces.stub(:FilterDevices) { NETCONFIG_ITEMS }
      expect(Yast::LanItems.getNetworkInterfaces).to match_array(EXPECTED_INTERFACES)
    end
end
