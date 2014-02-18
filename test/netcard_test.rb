#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

HWINFO_DEVICE_DESC = "Intel Ethernet controller"
HWINFO_DEVICE_MAC = "00:01:02:03:04:05"
HWINFO_DEVICE_BUS = "pci"
HWINFO_DEVICE_BUSID = "0000:00:19.0"
HWINFO_DEVICE_NAME = "eth11"
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
  1 => {"ifcfg" => "bond0"},
  2 => {"ifcfg" => "eth1"},
  3 => {"ifcfg" => "br0"},
  4 => {"ifcfg" => "tun0"},
  5 => {"ifcfg" => "tap0"},
}

require "yast"

include Yast
include UIShortcuts
include I18n

Yast.import "LanItems"

describe "When querying netcard device name" do
  before(:each) do
    @lan_items = Yast::LanItems
    @lan_items.main

    # mocking only neccessary parts of Yast::LanItems so we need not to call
    # and mock inputs for Yast::LanItems.Read here
    @lan_items.Items = MOCKED_ITEMS
  end

  it "returns empty list when querying device name with nil or empty input" do
    [ nil, [] ].each { |i| expect(@lan_items.GetDeviceNames(i)).to be_empty }
  end

  it "can return list of device names available in the system" do
    expected_names = ["bond0", "br0", "eth1", "eth11", "tap0", "tun0"]

    expect(@lan_items.GetNetcardNames.sort).to eq expected_names
  end
end

describe "NetworkComplexInclude#HardwareName" do

  before(:each) do
    Yast.include self, "network/complex.rb"

    @hwinfo = MOCKED_ITEMS[0]["hwinfo"]
    @expected_desc = HWINFO_DEVICE_DESC
  end

  it "returns expected name when querying oldfashioned mac based id" do
    expect(HardwareName([@hwinfo], "id-#{HWINFO_DEVICE_MAC}"))
      .to eql @expected_desc
  end

  it "returns expected name when querying oldfashioned bus based id" do
    busid = "bus-#{HWINFO_DEVICE_BUS}-#{HWINFO_DEVICE_BUSID}"
    expect(HardwareName([@hwinfo], busid))
      .to eql @expected_desc
  end

  it "returns expected name when querying by device name" do
    expect(HardwareName([@hwinfo], HWINFO_DEVICE_NAME))
      .to eql @expected_desc
  end

  it "returns empty string when id is not given" do
    expect(HardwareName(@hwinfo, nil)).to be_empty
    expect(HardwareName(@hwinfo, "")).to be_empty
  end

  it "returns empty string when no hwinfo is available" do
    expect(HardwareName(nil, HWINFO_DEVICE_NAME)).to be_empty
    expect(HardwareName([], HWINFO_DEVICE_NAME)).to be_empty
  end

  it "returns empty string when querying unknown id" do
    expect(HardwareName(@hwinfo, "unknown")).to be_empty
  end
end

describe "LanItemsClass#BuildLanOverview" do
  before(:each) do
    @lan_items = Yast::LanItems
    @lan_items.main
    @lan_items.Items = MOCKED_ITEMS
  end

  it "returns description and uses custom name if present" do
    @lan_items.stub(:GetDeviceMap) { { "NAME" => "Custom name" } }

    @lan_items.BuildLanOverview
    @lan_items.Items.each_pair do |key, value|
      # it is not issue, really same index two times
      desc = value["table_descr"]["table_descr"].first

      if value["ifcfg"]
        expect(desc).to eql "Custom name"
      else
        expect(desc).not_to be_empty
      end
    end
  end

  it "returns description and uses type based name if hwinfo is not present" do
    @lan_items.stub(:GetDeviceMap) { { "NAME" => "" } }

    @lan_items.BuildLanOverview
    @lan_items.Items.each_pair do |key, value|
      desc = value["table_descr"]["table_descr"].first

      if !value["hwinfo"]
        dev_name = value["ifcfg"].to_s
        dev_type = Yast::NetworkInterfaces.GetType(dev_name)
        expected_dev_desc = Yast::NetworkInterfaces.GetDevTypeDescription(dev_type, true)
      else
        expected_dev_desc = value["hwinfo"]["name"]
      end

      expect(desc).not_to be_empty
      expect(desc).to eql expected_dev_desc
    end
  end
end
