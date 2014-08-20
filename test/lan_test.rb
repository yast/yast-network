#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "Lan"

describe "LanClass#Packages" do

  packages = {
    "iw" => "wlan",
    "vlan" => "vlan",
    "bridge-utils" => "br",
    "tunctl" => "tun"
  }


  packages.each do |pkg, type|
    it "lists '#{pkg}' package for #{type} device" do
      allow(Yast::NetworkInterfaces)
        .to receive(:List)
        .and_return([])
      allow(Yast::NetworkInterfaces)
        .to receive(:List)
        .with(type)
        .and_return(["place_holder"])
      allow(Yast::NetworkInterfaces)
        .to receive(:Locate)
        .and_return([])
      allow(Yast::NetworkService)
        .to receive(:is_network_manager)
        .and_return(false)

      expect(Yast::PackageSystem)
        .to receive(:Installed)
        .with(pkg)
        .at_least(:once)
        .and_return(false)
      expect(Yast::Lan.Packages).to include pkg
    end
  end

  it "lists wpa_supplicant package when WIRELESS_AUTH_MODE is psk or eap" do
    allow(Yast::NetworkInterfaces)
      .to receive(:List)
      .and_return([])
    allow(Yast::NetworkService)
      .to receive(:is_network_manager)
      .and_return(false)

    # when checking options, LanClass#Packages currently cares only if
    # WIRELESS_AUTH_MODE={psk, eap} is present
    expect(Yast::NetworkInterfaces)
      .to receive(:Locate)
      .with("WIRELESS_AUTH_MODE", /(psk|eap)/)
      .at_least(:once)
      .and_return(["place_holder"])
    expect(Yast::PackageSystem)
      .to receive(:Installed)
      .with("wpa_supplicant")
      .at_least(:once)
      .and_return(false)
    expect(Yast::Lan.Packages).to include "wpa_supplicant"
  end

  it "lists NetworkManager package when NetworkManager service is selected" do
    allow(Yast::NetworkInterfaces)
      .to receive(:List)
      .and_return([])
    allow(Yast::NetworkInterfaces)
      .to receive(:Locate)
      .and_return([])

    expect(Yast::NetworkService)
      .to receive(:is_network_manager)
      .and_return(true)
    expect(Yast::PackageSystem)
      .to receive(:Installed)
      .with("NetworkManager")
      .at_least(:once)
      .and_return(false)
    expect(Yast::Lan.Packages).to include "NetworkManager"
  end

end
