#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"

describe "LanItemsClass#IsItemConfigured" do
  it "succeeds when item has configuration" do
    allow(Yast::LanItems).to receive(:GetLanItem) { { "ifcfg" => "enp0s3" } }

    expect(Yast::LanItems.IsItemConfigured(0)).to be true
  end

  it "fails when item doesn't exist" do
    allow(Yast::LanItems).to receive(:GetLanItem) { {} }

    expect(Yast::LanItems.IsItemConfigured(0)).to be false
  end

  it "fails when item's configuration doesn't exist" do
    allow(Yast::LanItems).to receive(:GetLanItem) { { "ifcfg" => nil } }

    expect(Yast::LanItems.IsItemConfigured(0)).to be false
  end
end

describe "LanItemsClass#delete_dev" do
  MOCKED_ITEMS_DEL = {
    0 => {
      "ifcfg" => "enp0s3"
    }
  }.freeze

  before(:each) do
    Yast::LanItems.Items = MOCKED_ITEMS_DEL.dup
  end

  it "removes device config when found" do
    Yast::LanItems.delete_dev("enp0s3")
    expect(Yast::LanItems.Items).to be_empty
  end
end

describe "LanItemsClass#getNetworkInterfaces" do
  NETCONFIG_ITEMS = {
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
  }.freeze

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
  ].freeze

  it "returns list of known interfaces" do
    allow(Yast::NetworkInterfaces).to receive(:FilterDevices) { NETCONFIG_ITEMS }
    expect(Yast::LanItems.getNetworkInterfaces).to match_array(EXPECTED_INTERFACES)
  end
end

describe "LanItemsClass#s390_correct_lladdr" do
  Yast.import "Arch"

  before(:each) do
    allow(Yast::Arch)
      .to receive(:s390)
      .and_return(true)
  end

  it "fails if given lladdr is nil" do
    expect(Yast::LanItems.send(:s390_correct_lladdr, nil)).to be false
  end

  it "fails if given lladdr is empty" do
    expect(Yast::LanItems.send(:s390_correct_lladdr, "")).to be false
  end

  it "fails if given lladdr contains zeroes only" do
    expect(Yast::LanItems.send(:s390_correct_lladdr, "00:00:00:00:00:00")).to be false
  end

  it "succeeds if given lladdr contains valid MAC" do
    expect(Yast::LanItems.send(:s390_correct_lladdr, "0a:00:27:00:00:00")).to be true
  end
end
