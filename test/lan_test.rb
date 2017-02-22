#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "Lan"

describe "LanClass#Packages" do
  packages = {
    "iw"     => "wlan",
    "vlan"   => "vlan",
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

describe "LanClass#activate_network_service" do
  Yast.import "Stage"
  Yast.import "NetworkService"

  [0, 1].each do |linuxrc_usessh|
    ssh_flag = linuxrc_usessh != 0

    context format("when linuxrc %s usessh flag", ssh_flag ? "sets" : "doesn't set") do
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

describe "LanClass#Import" do
  it "flushes internal state of LanItems correctly when asked for reset" do
    AY_PROFILE = {
      "devices" => {
        "eth" => {
          "eth0" => {
            "BOOTPROTO" => "static",
            "BROADCAST" => "192.168.127.255",
            "IPADDR"    => "192.168.73.138",
            "NETMASK"   => "255.255.192.0",
            "STARTMODE" => "manual"
          }
        }
      }
    }.freeze

    expect(Yast::Lan.Import(AY_PROFILE)).to be true
    expect(Yast::LanItems.GetModified).to be true
    expect(Yast::LanItems.Items).not_to be_empty

    expect(Yast::Lan.Import({})).to be true
    expect(Yast::LanItems.GetModified).to be false
    expect(Yast::LanItems.Items).to be_empty
  end
end

describe "LanClass#Modified" do
  def reset_modification_statuses
    allow(Yast::LanItems).to receive(:GetModified).and_return false
    allow(Yast::DNS).to receive(:modified).and_return false
    allow(Yast::Routing).to receive(:Modified).and_return false
    allow(Yast::NetworkConfig).to receive(:Modified).and_return false
    allow(Yast::NetworkService).to receive(:Modified).and_return false
    allow(Yast::SuSEFirewall).to receive(:GetModified).and_return false
  end

  def expect_modification_succeedes(modname, method)
    reset_modification_statuses

    allow(modname)
      .to receive(method)
      .and_return true

    expect(modname.send(method)).to be true
    expect(Yast::Lan.Modified).to be true
  end

  it "returns true when LanItems module was modified" do
    expect_modification_succeedes(Yast::LanItems, :GetModified)
  end

  it "returns true when DNS module was modified" do
    expect_modification_succeedes(Yast::DNS, :modified)
  end

  it "returns true when Routing module was modified" do
    expect_modification_succeedes(Yast::Routing, :Modified)
  end

  it "returns true when NetworkConfig module was modified" do
    expect_modification_succeedes(Yast::NetworkConfig, :Modified)
  end

  it "returns true when NetworkService module was modified" do
    expect_modification_succeedes(Yast::NetworkService, :Modified)
  end

  it "returns true when SuSEFirewall module was modified" do
    expect_modification_succeedes(Yast::SuSEFirewall, :GetModified)
  end

  it "returns false when no module was modified" do
    reset_modification_statuses
    expect(Yast::Lan.Modified).to be false
  end
end
