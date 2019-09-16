#!/usr/bin/env rspec

# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

require "yast"

Yast.import "LanItems"
require "y2network/config"
require "y2network/interface"
require "y2network/routing"
require "y2network/route"
require "y2network/routing_table"

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

  context "when a type is given" do
    it "returns the list of known interfaces of the given type" do
      allow(Yast::NetworkInterfaces).to receive(:FilterDevices) { NETCONFIG_ITEMS }
      expect(Yast::LanItems.getNetworkInterfaces("br")).to eql(["br0"])
    end
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

describe "LanItems#find_type_ifaces" do
  let(:mocked_items) do
    {
      0 => { "ifcfg" => "eth0" },
      1 => { "hwinfo" => { "dev_name" => "enp0s3" } },
      2 => { "ifcfg" => "bond0" }
    }
  end

  before(:each) do
    allow(Yast::LanItems).to receive(:Items).and_return(mocked_items)

    allow(Yast::LanItems).to receive(:GetDeviceType).and_return("eth")
    allow(Yast::LanItems).to receive(:GetDeviceType).with(0).and_return("eth")
    allow(Yast::LanItems).to receive(:GetDeviceType).with(1).and_return("eth")
    allow(Yast::LanItems).to receive(:GetDeviceType).with(2).and_return("bond")
  end

  it "lists all eth devices when asked for" do
    expect(Yast::LanItems.send(:find_type_ifaces, "eth")).to eql ["eth0", "enp0s3"]
  end

  it "returns an empty array when invalid type is given" do
    expect(Yast::LanItems.send(:find_type_ifaces, nil)).to eql []
  end
end

context "When proposing device names candidates" do
  before(:each) do
    allow(Yast::LanItems).to receive(:find_type_ifaces).and_return([])
    allow(Yast::LanItems).to receive(:find_type_ifaces).with("eth").and_return(["eth0", "eth2", "eth3"])
  end

  describe "LanItems#new_type_device" do
    it "generates a valid device name" do
      expect(Yast::LanItems.new_type_device("br")).to eql "br0"
      expect(Yast::LanItems.new_type_device("eth")).to eql "eth1"
    end

    it "raises an error when no type is provided" do
      expect { Yast::LanItems.new_type_device(nil) }.to raise_error(ArgumentError)
    end
  end

  describe "LanItems#new_type_devices" do
    it "generates as many new device names as requested" do
      candidates = Yast::LanItems.new_type_devices("eth", 10)

      expect(candidates.size).to eql 10
      expect(candidates).not_to include("eth0", "eth2", "eth3")
    end

    it "returns empty lists for device name count < 1" do
      expect(Yast::LanItems.new_type_devices("eth", 0)).to be_empty
      expect(Yast::LanItems.new_type_devices("eth", -1)).to be_empty
    end
  end

end

describe "LanItems#dhcp_ntp_servers" do
  it "lists ntp servers for every device which provides them" do
    result = {
      "eth0" => ["1.0.0.1"],
      "eth1" => ["1.0.0.2", "1.0.0.3"]
    }

    allow(Yast::LanItems)
      .to receive(:parse_ntp_servers)
      .and_return([])
    allow(Yast::LanItems)
      .to receive(:parse_ntp_servers)
      .with("eth0")
      .and_return(["1.0.0.1"])
    allow(Yast::LanItems)
      .to receive(:parse_ntp_servers)
      .with("eth1")
      .and_return(["1.0.0.2", "1.0.0.3"])
    allow(Yast::LanItems)
      .to receive(:find_dhcp_ifaces)
      .and_return(["eth0", "eth1", "eth2"])

    expect(Yast::LanItems.dhcp_ntp_servers).to eql result
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

describe "LanItems renaming methods" do
  let(:renamed_to) { nil }
  let(:current) { 0 }
  let(:item_0) do
    {
      "ifcfg"      => "eth0",
      "renamed_to" => renamed_to
    }
  end

  before do
    allow(Yast::LanItems).to receive(:Items).and_return(0 => item_0)
  end

  describe "LanItems.add_device_to_routing" do
    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:wlan0) { Y2Network::Interface.new("wlan0") }
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, wlan0]) }

    let(:yast_config) do
      instance_double(Y2Network::Config, interfaces: interfaces, routing: double("routing"))
    end

    before do
      allow(Y2Network::Config).to receive(:find).with(:yast).and_return(yast_config)
      allow(Yast::LanItems).to receive(:current_name).and_return("wlan1")
    end

    context "when a device name is given" do
      it "adds a new device with the given name" do
        Yast::LanItems.add_device_to_routing("br0")
        names = yast_config.interfaces.map(&:name)
        expect(names).to include("br0")
      end
    end

    context "when no device name is given" do
      it "adds a new device with the current device name" do
        Yast::LanItems.add_device_to_routing
        names = yast_config.interfaces.map(&:name)
        expect(names).to include("wlan1")
      end
    end

    context "when the interface already exists" do
      before do
        allow(Yast::LanItems).to receive(:current_name).and_return("wlan0")
      end

      it "does not add any interface" do
        Yast::LanItems.add_device_to_routing
        names = yast_config.interfaces.map(&:name)
        expect(names).to eq(["eth0", "wlan0"])
      end
    end
  end

  describe "LanItems.rename_current_device_in_routing" do
    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:wlan0) { Y2Network::Interface.new("wlan0") }
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, wlan0]) }
    let(:yast_config) do
      instance_double(Y2Network::Config, interfaces: interfaces, routing: double("routing"))
    end

    before do
      allow(Y2Network::Config).to receive(:find).with(:yast).and_return(yast_config)
      allow(Yast::LanItems).to receive(:current_name).and_return("wlan1")
    end

    it "updates the list of Routing devices with current device names" do
      Yast::LanItems.rename_current_device_in_routing("wlan0")
      new_names = yast_config.interfaces.map(&:name)
      expect(new_names).to eq(["eth0", "wlan1"])
    end
  end

  describe "LanItems.remove_current_device_from_routing" do
    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:wlan0) { Y2Network::Interface.new("wlan0") }
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, wlan0]) }

    let(:yast_config) do
      instance_double(Y2Network::Config, interfaces: interfaces, routing: double("routing"))
    end

    before do
      allow(Y2Network::Config).to receive(:find).with(:yast).and_return(yast_config)
      allow(Yast::LanItems).to receive(:current_name).and_return("wlan0")
    end

    it "removes the device" do
      Yast::LanItems.remove_current_device_from_routing
      names = yast_config.interfaces.map(&:name)
      expect(names).to eq(["eth0"])
    end
  end

  describe "LanItems.update_routing_devices?" do
    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:wlan0) { Y2Network::Interface.new("wlan0") }
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, wlan0]) }

    let(:yast_config) do
      instance_double(Y2Network::Config, interfaces: interfaces, routing: double("routing"))
    end

    before do
      allow(Y2Network::Config).to receive(:find).with(:yast).and_return(yast_config)
      allow(Yast::LanItems).to receive(:current_name).and_return(current_name)
    end

    context "when there are no changes in the device names" do
      let(:current_name) { "eth0" }

      it "returns false" do
        expect(Yast::LanItems.update_routing_devices?).to eql(false)
      end
    end

    context "when some interface have been renaming and Routing device names differs" do
      let(:current_name) { "eth1" }

      it "returns true" do
        expect(Yast::LanItems.update_routing_devices?).to eql(true)
      end
    end
  end

  describe "LanItems.move_routes" do
    let(:routing) { Y2Network::Routing.new(tables: [table1]) }
    let(:table1) { Y2Network::RoutingTable.new(routes) }
    let(:routes) { [route] }
    let(:route) do
      Y2Network::Route.new(to:        :default,
                           gateway:   IPAddr.new("192.168.122.1"),
                           interface: eth0)
    end
    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:br0) { Y2Network::Interface.new("br0") }
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, br0]) }
    let(:yast_config) do
      instance_double(Y2Network::Config, interfaces: interfaces, routing: routing)
    end

    before do
      allow(Y2Network::Config).to receive(:find).with(:yast).and_return(yast_config)
    end

    it "assigns all the 'from' routes to the 'to' interface" do
      expect { Yast::LanItems.move_routes("eth0", "br0") }
        .to change { route.interface }.from(eth0).to(br0)
    end
  end
end
