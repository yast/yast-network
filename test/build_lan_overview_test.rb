#!/usr/bin/env rspec

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

  # targeted mainly against bnc#906694
  it "returns translated network device textual description for wlan device" do
    allow(Yast::LanItems)
      .to receive(:Items)
      .and_return(wlan_items)
    allow(Yast::LanItems)
      .to receive(:GetDeviceMap)
      .and_return(wlan_ifcfg)
    allow(Yast::NetworkInterfaces)
      .to receive(:Current)
      .and_return(wlan_ifcfg)
    allow(FastGettext)
      .to receive(:locale)
      .and_return("de")

    # HACK: locale search path
    Yast::I18n::LOCALE_DIR = File.expand_path("../locale", __FILE__)

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
