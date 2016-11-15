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
  before(:each) do
    Yast::LanItems.Items = {
      0 => {
        "ifcfg" => "enp0s3"
      }
    }
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

describe "LanItems#GetItemUdev" do
  def check_GetItemUdev(key, expected_value)
    expect(Yast::LanItems.GetItemUdev(key)).to eql expected_value
  end

  context "when current item has an udev rule associated" do
    BUSID = "0000:00:00.0".freeze

    before(:each) do
      allow(Yast::LanItems)
        .to receive(:getCurrentItem)
        .and_return("udev" => { "net" => ["KERNELS==\"#{BUSID}\""] })
    end

    it "returns proper value when key exists" do
      check_GetItemUdev("KERNELS", BUSID)
    end

    it "returns an empty string when key doesn't exist" do
      check_GetItemUdev("NAME", "")
    end
  end

  context "when current item doesn't have an udev rule associated" do
    MAC = "00:11:22:33:44:55".freeze

    before(:each) do
      allow(Yast::LanItems)
        .to receive(:GetLanItem)
        .and_return("hwinfo" => { "mac" => MAC }, "ifcfg" => "eth0")
    end

    it "returns proper value when key exists" do
      check_GetItemUdev("ATTR{address}", MAC)
    end

    it "returns an empty string when key doesn't exist" do
      check_GetItemUdev("KERNELS", "")
    end
  end
end

describe "LanItems#RemoveItemUdev" do
  let(:rule) { { 0 => { "udev" => { "net" => ["KEY_TO_DELETE==\"VALUE\"", "OTHER_KEY"] } } } }
  before(:each) do
    Yast::LanItems.Items = rule
    Yast::LanItems.current = 0
  end

  context "when the current item has an udev rule associated" do
    it "removes the given key from the current rule if exists" do
      Yast::LanItems.RemoveItemUdev("KEY_TO_DELETE")

      expect(Yast::LanItems.GetItemUdevRule(0)).to eql(["OTHER_KEY"])
    end

    it "the current rule keeps untouched if the given key does not exist" do
      Yast::LanItems.RemoveItemUdev("NOT_PRESENT_KEY")

      expect(Yast::LanItems.GetItemUdevRule(0))
        .to eql(["KEY_TO_DELETE==\"VALUE\"", "OTHER_KEY"])
    end
  end

  context "when the current item doesn't have an udev rule associated" do
    let(:rule) { { 0 => { "ifcfg" => "eth0" } } }

    it "returns nil" do
      expect(Yast::LanItems.RemoveItemUdev("KEY_TO_DELETE")).to eql(nil)
    end
  end
end

describe "#update_item_udev_rule!" do
  let(:hwinfo) { { "dev_name" => "test0", "busid" => "00:08:00", "mac" => "01:02:03:04:05" } }
  let(:udev_net) { ["ATTR{address}==\"01:02:03:04:05\"", "KERNEL==\"eth*\"", "NAME=\"test0\""] }
  let(:rule) { { 0 => { "hwinfo" => hwinfo, "udev" => { "net" => udev_net } } } }

  before do
    Yast::LanItems.Items = rule
    Yast::LanItems.current = 0
    allow(Yast::LanItems).to receive(:dev_port).and_return("0")
  end

  context "when the given rule key is :bus_id" do
    it "uses KERNELS attribute with busid match instead of mac address" do
      allow(Yast::LanItems).to receive(:dev_port?).and_return(false)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["ATTR{address}==\"01:02:03:04:05\"", "KERNEL==\"eth*\"", "NAME=\"test0\""])
      Yast::LanItems.update_item_udev_rule!(:bus_id)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["KERNEL==\"eth*\"", "KERNELS==\"00:08:00\"", "NAME=\"test0\""])
    end

    it "adds the dev_port to the current rule if present in sysfs" do
      allow(Yast::LanItems).to receive(:dev_port?).and_return(true)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["ATTR{address}==\"01:02:03:04:05\"", "KERNEL==\"eth*\"", "NAME=\"test0\""])
      Yast::LanItems.update_item_udev_rule!(:bus_id)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["KERNEL==\"eth*\"", "ATTR{dev_port}==\"0\"", "KERNELS==\"00:08:00\"", "NAME=\"test0\""])
    end
  end

  context "when the given rule key is :mac" do
    let(:udev_net) { ["KERNEL==\"eth*\"", "KERNELS==\"00:08:00\"", "NAME=\"test0\""] }

    it "uses mac attribute" do
      allow(Yast::LanItems).to receive(:dev_port?).and_return(false)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["KERNEL==\"eth*\"", "KERNELS==\"00:08:00\"", "NAME=\"test0\""])
      Yast::LanItems.update_item_udev_rule!(:mac)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["KERNEL==\"eth*\"", "ATTR{address}==\"01:02:03:04:05\"", "NAME=\"test0\""])
    end

    context "and the current item has got a dev port" do
      let(:udev_net) { ["KERNEL==\"eth*\"", "ATTR{dev_port}==\"0\"", "KERNELS==\"00:08:00\"", "NAME=\"test0\""] }

      it "removes the dev_port from current rule if present" do
        allow(Yast::LanItems).to receive(:dev_port?).and_return(true)
        expect(Yast::LanItems.Items[0]["udev"]["net"])
          .to eql(["KERNEL==\"eth*\"", "ATTR{dev_port}==\"0\"", "KERNELS==\"00:08:00\"", "NAME=\"test0\""])
        Yast::LanItems.update_item_udev_rule!(:mac)
        expect(Yast::LanItems.Items[0]["udev"]["net"])
          .to eql(["KERNEL==\"eth*\"", "ATTR{address}==\"01:02:03:04:05\"", "NAME=\"test0\""])
      end
    end
  end
end
