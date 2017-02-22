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
  let(:hwinfo) { { "dev_name" => "test0", "busid" => "0000:08:00.0", "mac" => "24:be:05:ce:1e:91" } }
  let(:udev_net) { ["ATTR{address}==\"24:be:05:ce:1e:91\"", "KERNEL==\"eth*\"", "NAME=\"test0\""] }
  let(:rule) { { 0 => { "hwinfo" => hwinfo, "udev" => { "net" => udev_net } } } }

  before do
    Yast::LanItems.Items = rule
    Yast::LanItems.current = 0
    # The current item hasn't got a dev_port
    allow(Yast::LanItems).to receive(:dev_port).and_return("")
  end

  context "when the given rule key is :bus_id" do
    it "uses KERNELS attribute with busid match instead of mac address" do
      expect(Yast::LanItems.Items[0]["udev"]["net"]).to eql(udev_net)
      Yast::LanItems.update_item_udev_rule!(:bus_id)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["KERNEL==\"eth*\"", "KERNELS==\"0000:08:00.0\"", "NAME=\"test0\""])
    end

    context "and the dev_port is available via sysfs" do
      it "also adds the dev_port to the current rule" do
        allow(Yast::LanItems).to receive(:dev_port).and_return("0")
        expect(Yast::LanItems.Items[0]["udev"]["net"]).to eql(udev_net)
        Yast::LanItems.update_item_udev_rule!(:bus_id)
        expect(Yast::LanItems.Items[0]["udev"]["net"])
          .to eql(["KERNEL==\"eth*\"", "ATTR{dev_port}==\"0\"", "KERNELS==\"0000:08:00.0\"", "NAME=\"test0\""])
      end
    end
  end

  context "when the given rule key is :mac" do
    let(:udev_net) { ["KERNEL==\"eth*\"", "KERNELS==\"0000:08:00.0\"", "NAME=\"test0\""] }

    it "uses mac attribute" do
      expect(Yast::LanItems.Items[0]["udev"]["net"]).to eql(udev_net)
      Yast::LanItems.update_item_udev_rule!(:mac)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["KERNEL==\"eth*\"", "ATTR{address}==\"24:be:05:ce:1e:91\"", "NAME=\"test0\""])
    end

    context "and the current item has got a dev port" do
      let(:udev_net) { ["KERNEL==\"eth*\"", "ATTR{dev_port}==\"0\"", "KERNELS==\"0000:08:00.0\"", "NAME=\"test0\""] }

      it "removes the dev_port from current rule if present" do
        expect(Yast::LanItems.Items[0]["udev"]["net"]).to eql(udev_net)
        Yast::LanItems.update_item_udev_rule!(:mac)
        expect(Yast::LanItems.Items[0]["udev"]["net"])
          .to eql(["KERNEL==\"eth*\"", "ATTR{address}==\"24:be:05:ce:1e:91\"", "NAME=\"test0\""])
      end
    end
  end

  context "when not supported key is given" do
    it "raises an ArgumentError exception" do
      expect { Yast::LanItems.update_item_udev_rule!(:other) }.to raise_error(ArgumentError)
    end
  end

  context "when no parameters is given" do
    it "uses :mac as default" do
      expect(Yast::LanItems).to receive(:RemoveItemUdev).with("ATTR{dev_port}")
      expect(Yast::LanItems).to receive(:ReplaceItemUdev)

      Yast::LanItems.update_item_udev_rule!
    end
  end
end

describe "DHCLIENT_SET_HOSTNAME helpers" do
  def mock_items(dev_maps)
    # mock LanItems#Items
    item_maps = dev_maps.keys.map { |dev| { "ifcfg" => dev } }
    lan_items = [*0..dev_maps.keys.size - 1].zip(item_maps).to_h
    allow(Yast::LanItems)
      .to receive(:Items)
      .and_return(lan_items)

    # mock each device sysconfig map
    allow(Yast::LanItems)
      .to receive(:GetDeviceMap)
      .and_return({})

    lan_items.each_pair do |index, item_map|
      allow(Yast::LanItems)
        .to receive(:GetDeviceMap)
        .with(index)
        .and_return(dev_maps[item_map["ifcfg"]])
      allow(Yast::LanItems)
        .to receive(:GetDeviceName)
        .with(index)
        .and_return(item_map["ifcfg"])
    end
  end

  describe "LanItems#find_dhcp_ifaces" do
    let(:dhcp_maps) do
      {
        "eth0" => { "BOOTPROTO" => "dhcp" },
        "eth1" => { "BOOTPROTO" => "dhcp4" },
        "eth2" => { "BOOTPROTO" => "dhcp6" },
        "eth3" => { "BOOTPROTO" => "dhcp+autoip" }
      }.freeze
    end
    let(:non_dhcp_maps) do
      {
        "eth4" => { "BOOTPROTO" => "static" },
        "eth5" => { "BOOTPROTO" => "none" }
      }.freeze
    end
    let(:dhcp_invalid_maps) do
      { "eth6" => { "BOOT" => "dhcp" } }.freeze
    end

    it "finds all dhcp aware interfaces" do
      mock_items(dhcp_maps.merge(non_dhcp_maps.merge(dhcp_invalid_maps)))

      expect(Yast::LanItems.find_dhcp_ifaces).to eql ["eth0", "eth1", "eth2", "eth3"]
    end

    it "returns empty array when no dhcp configuration is present" do
      mock_items(non_dhcp_maps.merge(dhcp_invalid_maps))

      expect(Yast::LanItems.find_dhcp_ifaces).to eql []
    end
  end

  describe "LanItems#find_set_hostname_ifaces" do
    let(:dhcp_yes_maps) do
      {
        "eth0" => { "DHCLIENT_SET_HOSTNAME" => "yes" }
      }.freeze
    end
    let(:dhcp_no_maps) do
      {
        "eth1" => { "DHCLIENT_SET_HOSTNAME" => "no" }
      }.freeze
    end
    let(:dhcp_invalid_maps) do
      { "eth2" => { "DHCP_SET_HOSTNAME" => "yes" } }.freeze
    end

    it "returns a list of all devices with DHCLIENT_SET_HOSTNAME=\"yes\"" do
      mock_items(dhcp_yes_maps.merge(dhcp_no_maps.merge(dhcp_invalid_maps)))

      expect(Yast::LanItems.find_set_hostname_ifaces).to eql ["eth0"]
    end

    it "returns empty list when no DHCLIENT_SET_HOSTNAME=\"yes\" is found" do
      mock_items(dhcp_no_maps.merge(dhcp_invalid_maps))

      expect(Yast::LanItems.find_set_hostname_ifaces).to be_empty
    end
  end

  describe "LanItems#clear_set_hostname" do
    let(:dhcp_yes_maps) do
      {
        "eth0" => { "DHCLIENT_SET_HOSTNAME" => "yes" }
      }.freeze
    end
    let(:dhcp_no_maps) do
      {
        "eth1" => { "DHCLIENT_SET_HOSTNAME" => "no" }
      }.freeze
    end
    let(:no_dhclient_maps) do
      { "eth6" => { "BOOT" => "dhcp" } }.freeze
    end

    it "clears all DHCLIENT_SET_HOSTNAME options" do
      dhclient_maps = dhcp_yes_maps.merge(dhcp_no_maps)
      mock_items(dhclient_maps.merge(no_dhclient_maps))

      expect(Yast::LanItems)
        .to receive(:SetDeviceMap)
        .with(kind_of(Integer), "DHCLIENT_SET_HOSTNAME" => nil)
        .twice
      expect(Yast::LanItems)
        .to receive(:SetModified)
        .at_least(:once)

      ret = Yast::LanItems.clear_set_hostname

      expect(ret).to eql dhclient_maps.keys
    end
  end

  describe "LanItems#valid_dhcp_cfg?" do
    def mock_dhcp_setup(ifaces, global)
      allow(Yast::LanItems)
        .to receive(:find_set_hostname_ifaces)
        .and_return(ifaces)
      allow(Yast::DNS)
        .to receive(:dhcp_hostname)
        .and_return(global)
    end

    it "fails when DHCLIENT_SET_HOSTNAME is set for multiple ifaces" do
      mock_dhcp_setup(["eth0", "eth1"], false)

      expect(Yast::LanItems.invalid_dhcp_cfgs).not_to include("dhcp")
      expect(Yast::LanItems.invalid_dhcp_cfgs).to include("ifcfg-eth0")
      expect(Yast::LanItems.invalid_dhcp_cfgs).to include("ifcfg-eth1")
      expect(Yast::LanItems.valid_dhcp_cfg?).to be false
    end

    it "fails when DHCLIENT_SET_HOSTNAME is set globaly even in an ifcfg" do
      mock_dhcp_setup(["eth0"], true)

      expect(Yast::LanItems.invalid_dhcp_cfgs).to include("dhcp")
      expect(Yast::LanItems.invalid_dhcp_cfgs).to include("ifcfg-eth0")
      expect(Yast::LanItems.valid_dhcp_cfg?).to be false
    end

    it "succeedes when DHCLIENT_SET_HOSTNAME is set for one iface" do
      mock_dhcp_setup(["eth0"], false)

      expect(Yast::LanItems.invalid_dhcp_cfgs).to be_empty
      expect(Yast::LanItems.valid_dhcp_cfg?).to be true
    end

    it "succeedes when only global DHCLIENT_SET_HOSTNAME is set" do
      mock_dhcp_setup([], true)

      expect(Yast::LanItems.invalid_dhcp_cfgs).to be_empty
      expect(Yast::LanItems.valid_dhcp_cfg?).to be true
    end
  end
end
