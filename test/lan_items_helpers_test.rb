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
