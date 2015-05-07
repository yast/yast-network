#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "Lan"

describe "LanClass#Packages" do
  packages = {
    "iw"           => "wlan",
    "vlan"         => "vlan",
    "bridge-utils" => "br",
    "tunctl"       => "tun"
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

describe "LanClass#activate_network_service" do
  Yast.import "Stage"
  Yast.import "NetworkService"

  [0, 1].each do |linuxrc_usessh|
    ssh_flag = linuxrc_usessh != 0

    context "when linuxrc %s usessh flag" % ssh_flag ? "sets" : "doesn't set" do
      before(:each) do
        allow(Yast::Linuxrc)
          .to receive(:usessh)
          .and_return(ssh_flag)
      end

      context "when asked in normal mode" do
        before(:each) do
          allow(Yast::Stage)
            .to receive(:normal)
            .and_return(true)
        end

        it "tries to reload network service" do
          expect(Yast::NetworkService)
            .to receive(:ReloadOrRestart)

          Yast::Lan.send(:activate_network_service)
        end
      end

      context "when asked during installation" do
        before(:each) do
          allow(Yast::Stage)
            .to receive(:normal)
            .and_return(false)
        end

        it "updates network service according usessh flag" do
          if ssh_flag
            expect(Yast::NetworkService)
              .not_to receive(:ReloadOrRestart)
          else
            expect(Yast::NetworkService)
              .to receive(:ReloadOrRestart)
          end

          Yast::Lan.send(:activate_network_service)
        end
      end
    end
  end
end
