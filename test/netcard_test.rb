#! /usr/bin/env rspec

require_relative "test_helper"

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
}

require "yast"

Yast.import "LanItems"

describe "When querying netcard device name" do
  before(:each) do
    @lan_items = Yast::LanItems
    @lan_items.main

    # mocking only neccessary parts of Yast::LanItems so we need not to call
    # and mock inputs for Yast::LanItems.Read here
    @lan_items.Items = Yast.deep_copy(MOCKED_ITEMS)
  end

  it "returns empty list when querying device name with nil or empty input" do
    [nil, []].each { |i| expect(@lan_items.GetDeviceNames(i)).to be_empty }
  end

  it "can return list of device names available in the system" do
    expected_names = ["bond0", "br0", "eth1", "eth11", "enp0s3", "tap0", "tun0"].sort

    expect(@lan_items.GetNetcardNames.sort).to eq expected_names
  end
end

describe "NetworkComplexInclude#HardwareName" do
  include Yast::UIShortcuts
  include Yast::I18n

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
    @lan_items.Items = Yast.deep_copy(MOCKED_ITEMS)
  end

  it "returns description and uses custom name if present" do
    allow(@lan_items).to receive(:GetDeviceMap) { { "NAME" => "Custom name" } }

    @lan_items.BuildLanOverview
    @lan_items.Items.each_pair do |_key, value|
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
    allow(@lan_items).to receive(:GetDeviceMap) { { "NAME" => "" } }

    @lan_items.BuildLanOverview
    @lan_items.Items.each_pair do |_key, value|
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

describe "LanItemsClass#DeleteItem" do
  before(:each) do
    @lan_items = Yast::LanItems
    @lan_items.main
    @lan_items.Items = Yast.deep_copy(MOCKED_ITEMS)
  end

  it "removes an existing item" do
    before_items = nil

    while before_items != @lan_items.Items && !@lan_items.Items.empty?
      @lan_items.current = 0

      item_name = @lan_items.GetCurrentName
      before_items = @lan_items.Items

      @lan_items.DeleteItem

      expect(@lan_items.FindAndSelect(item_name)).to be false
    end
  end

  it "removes only the configuration if the item has hwinfo" do
    before_size = @lan_items.Items.size
    item_name = "enp0s3"

    expect(@lan_items.FindAndSelect(item_name)).to be true

    @lan_items.DeleteItem

    expect(@lan_items.FindAndSelect(item_name)).to be false
    expect(@lan_items.Items.size).to eql before_size
  end
end

describe "LanItemsClass#GetItemName" do
  before(:each) do
    @lan_items = Yast::LanItems
    @lan_items.main
    @lan_items.Items = Yast.deep_copy(MOCKED_ITEMS)
  end

  it "returns name provided by hwinfo if not configured" do
    MOCKED_ITEMS.select { |_k, v| !v.key?("ifcfg") }.each_pair do |item_id, conf|
      expect(@lan_items.GetDeviceName(item_id)).to eql conf["hwinfo"]["dev_name"]
    end
  end

  it "returns name according configuration if available" do
    MOCKED_ITEMS.select { |_k, v| v.key?("ifcfg") }.each_pair do |item_id, conf|
      expect(@lan_items.GetDeviceName(item_id)).to eql conf["ifcfg"]
    end
  end
end

describe "LanItemsClass#SetItemName" do
  let(:new_name) { "new_name" }

  # this test covers bnc#914833
  it "doesn't try to update udev rules when none exists for the item" do
    allow(Yast::LanItems)
      .to receive(:Items)
      .and_return(MOCKED_ITEMS)

    item_id = Yast::LanItems.Items.find { |_k, v| !v.key?("udev") }.first
    expect(Yast::LanItems.SetItemName(item_id, new_name)).to eql new_name
  end
end

describe "LanItemsClass#FindAndSelect" do
  before(:each) do
    @lan_items = Yast::LanItems
    @lan_items.main
    @lan_items.Items = Yast.deep_copy(MOCKED_ITEMS)
  end

  it "finds configured device" do
    expect(@lan_items.FindAndSelect("enp0s3")).to be true
  end

  it "fails to find unconfigured device" do
    expect(@lan_items.FindAndSelect("nonexistent")).to be false
  end
end
