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

HWINFO_DEVICE_DESC = "Intel Ethernet controller".freeze
HWINFO_DEVICE_MAC = "00:01:02:03:04:05".freeze
HWINFO_DEVICE_BUS = "pci".freeze
HWINFO_DEVICE_BUSID = "0000:00:19.0".freeze
HWINFO_DEVICE_NAME = "eth11".freeze
# hwinfo is based on real hwinfo netcard output
MOCKED_ITEMS = {
  # present but unconfigured devices
  0 => {
    "hwinfo" => {
      "name"          => HWINFO_DEVICE_DESC,
      "type"          => "eth",
      "udi"           => "",
      "sysfs_id"      => "/devices/pci0000:00/0000:00:19.0",
      "dev_name"      => HWINFO_DEVICE_NAME,
      "requires"      => [],
      "modalias"      => "pci:v00008086d00001502sv000017AAsd000021F3bc02sc00i00",
      "unique"        => "rBUF.41x4AT4gee2",
      "driver"        => "e1000e",
      "num"           => 0,
      "drivers"       => [
        {
          "active"   => true,
          "modprobe" => true,
          "modules"  => [
            [
              "e1000e",
              ""
            ]
          ]
        }
      ],
      "active"        => true,
      "module"        => "e1000e",
      "options"       => "",
      "bus"           => HWINFO_DEVICE_BUS,
      "busid"         => HWINFO_DEVICE_BUSID,
      "mac"           => HWINFO_DEVICE_MAC,
      "permanent_mac" => HWINFO_DEVICE_MAC,
      "link"          => nil,
      "wl_channels"   => nil,
      "wl_bitrates"   => nil,
      "wl_auth_modes" => nil,
      "wl_enc_modes"  => nil
    },
    "udev"   => {
      "net"    => [],
      "driver" => ""
    }
  },
  # devices with configuration, but not present
  1 => { "ifcfg" => "bond0" },
  2 => { "ifcfg" => "eth1" },
  3 => { "ifcfg" => "br0" },
  4 => { "ifcfg" => "tun0" },
  5 => { "ifcfg" => "tap0" },
  # devices with configuration and hwinfo
  6 => {
    "ifcfg"  => "enp0s3",
    "hwinfo" => {
      "name"     => "SUSE test card",
      "dev_name" => "enp0s3"
    }
  }
}.freeze

require "yast"

class NetworkComplexIncludeClass < Yast::Module
  def initialize
    Yast.include self, "network/complex.rb"
  end
end

describe "NetworkComplexInclude#HardwareName" do
  subject { NetworkComplexIncludeClass.new }

  before(:each) do
    @hwinfo = MOCKED_ITEMS[0]["hwinfo"]
    @expected_desc = HWINFO_DEVICE_DESC
  end

  it "returns expected name when querying oldfashioned mac based id" do
    expect(subject.HardwareName([@hwinfo], "id-#{HWINFO_DEVICE_MAC}"))
      .to eql @expected_desc
  end

  it "returns expected name when querying oldfashioned bus based id" do
    busid = "bus-#{HWINFO_DEVICE_BUS}-#{HWINFO_DEVICE_BUSID}"
    expect(subject.HardwareName([@hwinfo], busid))
      .to eql @expected_desc
  end

  it "returns expected name when querying by device name" do
    expect(subject.HardwareName([@hwinfo], HWINFO_DEVICE_NAME))
      .to eql @expected_desc
  end

  it "returns empty string when id is not given" do
    expect(subject.HardwareName(@hwinfo, nil)).to be_empty
    expect(subject.HardwareName(@hwinfo, "")).to be_empty
  end

  it "returns empty string when no hwinfo is available" do
    expect(subject.HardwareName(nil, HWINFO_DEVICE_NAME)).to be_empty
    expect(subject.HardwareName([], HWINFO_DEVICE_NAME)).to be_empty
  end

  it "returns empty string when querying unknown id" do
    expect(subject.HardwareName(@hwinfo, "unknown")).to be_empty
  end
end
