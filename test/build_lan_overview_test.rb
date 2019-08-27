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

include Yast::I18n

describe "LanItemsClass#BuildLanOverview" do
  let(:unknown_device_overview) do
    ["<ul><li><p>Unknown Network Device<br>Not configured yet.</p></li></ul>", []]
  end
  let(:german_translation_overview) do
    [
      "<ul><li><p>WiFi Link 6000 Series<br>Ohne Adresse konfiguriert (KEINE) <font color=\"red\">Warnung: Es wird keine Verschl\u00FCsselung verwendet.</font> <a href=\"lan--wifi-encryption-wlan0\">\u00C4ndern Sie dies.</a></p></li></ul>",
      ["lan--wifi-encryption-wlan0"]
    ]
  end
  let(:wlan_items) do
    {
      0 => {
        "ifcfg" => "wlan0"
      }
    }
  end
  let(:wlan_ifcfg) do
    {
      "BOOTPROTO"          => "none",
      "NAME"               => "WiFi Link 6000 Series",
      "WIRELESS_AUTH_MODE" => "open",
      "WIRELESS_KEY_0"     => ""
    }
  end
  let(:lan_items) do
    {
      0 => { "hwinfo" => {
        "name"     => "Ethernet Card 0",
        "type"     => "eth",
        "udi"      => "",
        "sysfs_id" => "/devices/pci0000:00/0000:00:03.0/virtio0",
        "dev_name" => "eth0",
        "requires" => [],
        "modalias" => "virtio:d00000001v00001AF4",
        "unique"   => "vWuh.VIRhsc57kTD",
        "driver"   => "virtio_net",
        "num"      => 0,
        "active"   => true,
        "module"   => "virtio_net",
        "bus"      => "Virtio",
        "busid"    => "virtio0",
        "mac"      => "02:00:00:12:34:56",
        "link"     => true
      },
             "udev"   => {
               "net"    => ["SUBSYSTEM==\"net\"", "ACTION==\"add\"", "DRIVERS==\"virtio-pci\"",
                            "ATTR{dev_id}==\"0x0\"", "KERNELS==\"0000:00:03.0\"",
                            "ATTR{type}==\"1\"", "KERNEL==\"eth*\"", "NAME=\"eth0\""],
               "driver" => ""
             },
             "ifcfg"  => "eth0" }
    }
  end
  let(:lan_ifcfg) do
    { "STARTMODE"                  => "nfsroot",
      "BOOTPROTO"                  => "dhcp",
      "DHCLIENT_SET_DEFAULT_ROUTE" => "yes" }
  end
  let(:interfaces) { Y2Network::InterfacesCollection.new([]) }

  before do
    allow(Y2Network::Config)
      .to receive(:find)
      .and_return(instance_double(Y2Network::Config, interfaces: interfaces))
  end

  # targeted mainly against bnc#906694
  context "with an wlan interface" do
    before do
      allow(Yast::LanItems)
        .to receive(:Items)
        .and_return(wlan_items)
      allow(Yast::LanItems)
        .to receive(:GetDeviceMap)
        .and_return(wlan_ifcfg)
      allow(Yast::NetworkInterfaces)
        .to receive(:Current)
        .and_return(wlan_ifcfg)
      allow(Yast::NetworkInterfaces)
        .to receive(:GetType)
        .and_call_original
      allow(Yast::NetworkInterfaces)
        .to receive(:GetType)
        .with("wlan0")
        .and_return("wlan")
      allow(FastGettext)
        .to receive(:locale)
        .and_return("de")
    end
    it "returns translated network device textual description for wlan device" do
      # locale search path
      stub_const("Yast::I18n::LOCALE_DIR", File.expand_path("../locale", __FILE__))

      textdomain("network")

      # other checks depends on this
      # - output of BuildLanOverview changes according number of devices
      # even for "failing" (unknown devices) path
      expect(Yast::LanItems.Items.size).to eql 1

      overview = Yast::LanItems.BuildLanOverview
      expect(overview).not_to eql unknown_device_overview
      expect(overview).to eql german_translation_overview
    end
  end

  context "with an lan interface" do
    before do
      allow(Yast::LanItems).to receive(:Items)
        .and_return(lan_items)
      allow(Yast::LanItems).to receive(:GetDeviceMap)
        .and_return(lan_ifcfg)
      allow(Yast::NetworkInterfaces).to receive(:Current)
        .and_return(lan_ifcfg)
    end
    it "returns description for lan device with the correct start option" do
      Yast::LanItems.BuildLanOverview
      expect(Yast::LanItems.Items.size).to eql 1
      expect(Yast::LanItems.Items[0]["table_descr"]["rich_descr"].include?("Started automatically at boot")).to eql(true)
    end
  end
end

describe "LanItemsClass#ip_overview" do
  # smoke test for bnc#1013684
  it "do not crash when devmap for staticaly configured device do not contain PREFIXLEN" do
    devmap = {
      "IPADDR"    => "1.1.1.1",
      "NETMASK"   => "255.255.0.0",
      "BOOTPROTO" => "static",
      "STARTMODE" => "auto"
    }

    expect { Yast::LanItems.ip_overview(devmap) }.not_to raise_error
  end
end
