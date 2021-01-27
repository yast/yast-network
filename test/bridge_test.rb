#! /usr/bin/env rspec

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

require "y2network/config"
require "y2network/interface"
require "y2network/type_detector"

Yast.import "Lan"
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

    allow(Y2Network::TypeDetector)
      .to receive(:type_of)
      .with(/eth[0-9]/)
      .and_return(Y2Network::InterfaceType::ETHERNET)
  end

  xdescribe "#GetBridgeableInterfaces" do
    # when converting to new API new API is used
    # for selecting bridgable devices but imports interfaces
    # from LanItems internally
    let(:config) { Y2Network::Config.new(source: :test) }
    let(:builder) { Y2Network::InterfaceConfigBuilder.for(Y2Network::InterfaceType::BRIDGE) }

    it "returns list of slave candidates" do
      pending "old API is dropped, so adapt it"
      allow(Y2Network::Config)
        .to receive(:find)
        .with(:yast)
        .and_return(config)

      builder.name = "br0"
      expect(builder.bridgeable_interfaces.map(&:name))
        .to match_array expected_bridgeable
    end
  end
end
