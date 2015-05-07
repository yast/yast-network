#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"

include Yast::UIShortcuts
include Yast::I18n

describe "LanItemsClass#BuildLanOverview" do
  let(:unknown_device_overview) {
    ["<ul><li><p>Unknown Network Device<br>Not configured yet.</p></li></ul>", []]
  }
  let(:german_translation_overview) {
    [
      "<ul><li><p>WiFi Link 6000 Series<br>Ohne Adresse konfiguriert (KEINE) <font color=\"red\">Warnung: Es wird keine Verschl\u00FCsselung verwendet.</font> <a href=\"lan--wifi-encryption-wlan0\">\u00C4ndern Sie dies.</a></p></li></ul>",
      ["lan--wifi-encryption-wlan0"]
    ]
  }
  let(:wlan_items) {
    {
      0 => {
        "ifcfg" => "wlan0"
      }
    }
  }
  let(:wlan_ifcfg) {
    {
      "BOOTPROTO"          => "none",
      "NAME"               => "WiFi Link 6000 Series",
      "WIRELESS_AUTH_MODE" => "open",
      "WIRELESS_KEY_0"     => ""
    }
  }

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

    # hack locale search path
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
