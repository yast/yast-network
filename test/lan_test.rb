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
require "y2network/config"
require "y2network/routing"
require "y2network/interface_config_builder"

Yast.import "Lan"

describe "LanClass" do
  subject { Yast::Lan }

  let(:system_config) { Y2Network::Config.new(interfaces: [], source: :sysconfig) }

  describe "#Packages" do
    before(:each) do
      allow(Yast::NetworkService)
        .to receive(:is_network_manager)
        .and_return(nm_enabled)
    end

    context "When NetworkManager is not going to be installed" do
      let(:nm_enabled) { false }

      before(:each) do
        allow(Yast::PackageSystem)
          .to receive(:Installed)
          .with("wpa_supplicant")
          .at_least(:once)
          .and_return(false)
      end

      it "always proposes wpa_supplicant" do
        expect(Yast::LanItems)
          .to receive(:find_type_ifaces)
          .with("wlan")
          .at_least(:once)
          .and_return(["place_holder"])

        expect(Yast::Lan.Packages).to include "wpa_supplicant"
      end
    end

    context "When NetworkManager is selected for the target" do
      let(:nm_enabled) { true }

      it "lists NetworkManager package" do
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
  end

  describe "#activate_network_service" do

    Yast.import "Stage"
    Yast.import "NetworkService"

    let(:yast_config) { instance_double(Y2Network::Config, "YaST", connections: collection) }
    let(:collection) { [eth0, eth1] }

    let(:eth0) { Y2Network::ConnectionConfig::Ethernet.new.tap { |c| c.name = "eth0" } }
    let(:eth1) { Y2Network::ConnectionConfig::Ethernet.new.tap { |c| c.name = "eth1" } }

    let(:installation) { false }

    before do
      subject.add_config(:yast, yast_config)
      allow(Yast::Stage).to receive(:normal).and_return(!installation)
      allow(Yast::Stage).to receive(:initial).and_return(installation)
    end

    [0, 1].each do |linuxrc_usessh|
      ssh_flag = linuxrc_usessh != 0

      context format("when linuxrc %s usessh flag", ssh_flag ? "sets" : "doesn't set") do
        before(:each) do
          allow(Yast::Linuxrc).to receive(:usessh).and_return(ssh_flag)
        end

        context "when asked in normal mode" do
          it "tries to reload network service" do
            expect(Yast::NetworkService)
              .to receive(:ReloadOrRestart)

            Yast::Lan.send(:activate_network_service)
          end
        end

        context "when asked during installation" do
          let(:installation) { true }

          if ssh_flag
            it "reloads configured connections" do
              expect(subject).to receive(:reload_config).with(["eth0", "eth1"])

              Yast::Lan.send(:activate_network_service)
            end
          else
            it "tries to reload or restart the networkservice" do
              expect(Yast::NetworkService)
                .to receive(:ReloadOrRestart)

              Yast::Lan.send(:activate_network_service)
            end
          end

        end
      end
    end
  end

  xdescribe "#Import" do
    let(:ay_profile) do
      {
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
      }
    end

    it "flushes internal state of LanItems correctly when asked for reset" do
      expect(Yast::Lan.Import(ay_profile)).to be true
      expect(Yast::Lan.GetModified).to be true
      expect(Yast::LanItems.Items).not_to be_empty

      expect(Yast::Lan.Import({})).to be true
      expect(Yast::Lan.GetModified).to be false
      expect(Yast::LanItems.Items).to be_empty
    end

    it "reads the current /etc/hosts entries" do
      expect(Yast::Host).to receive(:Read)

      Yast::Lan.Import(ay_profile)
    end
  end

  describe "#Modified" do
    let(:yast_config) { system_config.copy }

    before do
      allow(Yast::NetworkConfig).to receive(:Modified).and_return false
      allow(Yast::NetworkService).to receive(:Modified).and_return false
      allow(Yast::Host).to receive(:GetModified).and_return false

      Yast::Lan.add_config(:system, system_config)
      Yast::Lan.add_config(:yast, yast_config)
    end

    context "when the configuration was not changed" do
      it "returns false" do
        expect(Yast::Lan.Modified).to eq(false)
      end
    end

    context "when the configuration was changed" do
      before do
        yast_config.routing.forward_ipv4 = !system_config.routing.forward_ipv4
      end

      it "returns true" do
        expect(Yast::Lan.Modified).to eq(true)
      end
    end

    context "when the NetworkConfig module was modified" do
      before { allow(Yast::NetworkConfig).to receive(:Modified).and_return(true) }

      it "returns true" do
        expect(Yast::Lan.Modified).to eq(true)
      end
    end

    context "when the NetworkService module was modified" do
      before { allow(Yast::NetworkService).to receive(:Modified).and_return(true) }

      it "returns true" do
        expect(Yast::Lan.Modified).to eq(true)
      end
    end

    context "when the Host module was modified" do
      before { allow(Yast::Host).to receive(:GetModified).and_return(true) }

      it "returns true" do
        expect(Yast::Lan.Modified).to eq(true)
      end
    end
  end

  describe "#SetModified" do
    before do
      allow(Yast::NetworkConfig).to receive(:Modified).and_return false
      allow(Yast::NetworkService).to receive(:Modified).and_return false
      allow(Yast::Host).to receive(:GetModified).and_return false
    end

    it "changes Modified to true" do
      subject.main
      expect { subject.SetModified }.to change { subject.Modified }.from(false).to(true)
    end
  end

  describe "#readIPv6" do
    let(:sysctl_config_file) { CFA::SysctlConfig.new }

    before do
      allow(CFA::SysctlConfig).to receive(:new).and_return(sysctl_config_file)
      allow(sysctl_config_file).to receive(:load)
      sysctl_config_file.disable_ipv6 = disable_ipv6
    end

    context "when IPv6 is disabled" do
      let(:disable_ipv6) { true }

      it "returns false" do
        expect(Yast::Lan.readIPv6).to eq(false)
      end
    end

    context "when IPv6 is not disabled" do
      let(:disable_ipv6) { false }

      it "returns true" do
        expect(Yast::Lan.readIPv6).to eq(true)
      end
    end
  end

  describe "#readIPv6" do
    let(:sysctl_config_file) { CFA::SysctlConfig.new }

    before do
      allow(CFA::SysctlConfig).to receive(:new).and_return(sysctl_config_file)
      allow(sysctl_config_file).to receive(:load)
      allow(sysctl_config_file).to receive(:save)
      Yast::Lan.ipv6 = ipv6
    end

    context "when IPv6 is enabled" do
      let(:ipv6) { true }

      it "enables IPv6 in the sysctl_config configuration" do
        expect(sysctl_config_file).to receive(:disable_ipv6=).with(false)
        Yast::Lan.writeIPv6
      end

      it "enables IPv6 in the running system" do
        expect(Yast::SCR).to receive(:Execute).with(anything, /sysctl .+disable_ipv6=0/)
        Yast::Lan.writeIPv6
      end
    end

    context "when IPv6 is disabled" do
      let(:ipv6) { false }

      it "disables IPv6 in the sysctl_config configuration" do
        expect(sysctl_config_file).to receive(:disable_ipv6=).with(true)
        Yast::Lan.writeIPv6
      end

      it "disables IPv6 in the running system" do
        expect(Yast::SCR).to receive(:Execute).with(anything, /sysctl .+disable_ipv6=1/)
        Yast::Lan.writeIPv6
      end
    end
  end

  describe "#ProposeVirtualized" do
    let(:yast_config) { instance_double(Y2Network::Config, "YaST") }
    before do
      subject.add_config(:yast, yast_config)
    end

    it "creates a new configuration for virtualization" do
      expect_any_instance_of(Y2Network::VirtualizationConfig).to receive(:create)

      Yast::Lan.ProposeVirtualized
    end
  end

  describe "#FromAY" do
    it "makes a minimal structure from an empty input" do
      expected = {
        "config"     => { "dhcp"=>{} },
        "interfaces" => []
      }
      expect(Yast::Lan.FromAY({})).to eq(expected)
    end

    it "converts DHCP options" do
      input = {
        "dhcp_options" => {
          "dhclient_hostname_option" => "AUTO"
        },
        "dns"          => {
          "dhcp_hostname"      => false,
          "domain"             => "example.com",
          "hostname"           => "eg",
          "nameservers"        => ["10.10.0.100"],
          "resolv_conf_policy" => "auto",
          "searchlist"         => ["example.com"],
          "write_hostname"     => false
        }
      }
      expected_config = {
        "dhcp" => {
          "DHCLIENT_HOSTNAME_OPTION" => "AUTO",
          "DHCLIENT_SET_HOSTNAME"    => false
        }
      }

      actual = Yast::Lan.FromAY(input)
      expect(actual["config"]).to eq(expected_config)
    end
  end

  describe "#dhcp_ntp_servers" do
    subject { Yast::Lan }
    let(:running) { true }
    let(:nm_enabled) { true }
    let(:servers) do
      {
        "eth0" => ["0.pool.ntp.org", "1.pool.ntp.org"],
        "eth1" => ["1.pool.ntp.org", "2.pool.ntp.org"]
      }
    end

    before do
      allow(Yast::NetworkService).to receive(:isNetworkRunning).and_return(running)
      allow(Yast::NetworkService).to receive(:is_network_manager).and_return(nm_enabled)
      allow(Yast::LanItems).to receive(:dhcp_ntp_servers).and_return(servers)
    end

    context "when the network is not running" do
      let(:running) { false }
      it "returns an empty array" do
        expect(subject.dhcp_ntp_servers).to eq([])
      end
    end

    context "when NetworkManager is in use" do
      let(:nm_enabled) { true }
      it "returns an empty array" do
        expect(subject.dhcp_ntp_servers).to eq([])
      end
    end

    context "when wicked is in use" do
      let(:nm_enabled) { false }

      before do
        allow(Yast::Lan).to receive(:ReadWithCacheNoGUI)
      end

      it "reads the current network configuration" do
        expect(Yast::Lan).to receive(:ReadWithCacheNoGUI)
        subject.dhcp_ntp_servers
      end

      it "returns a list of the ntp_servers provided by dhcp " do
        expect(subject.dhcp_ntp_servers.sort)
          .to eql(["0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org"])
      end
    end
  end

  describe "#find_config" do
    let(:yast_config) { instance_double(Y2Network::Config, "YaST") }

    before do
      subject.main
      subject.add_config(:system, system_config)
      subject.add_config(:yast, yast_config)
    end

    it "retuns the network configuration with the given ID" do
      expect(subject.find_config(:yast)).to eq(yast_config)
    end

    context "when a network configuration with the given ID is not found" do
      it "returns nil" do
        expect(subject.find_config(:missing)).to be_nil
      end
    end
  end

  describe "#clear_configs" do
    before do
      subject.main
      subject.add_config(:system, system_config)
    end

    it "cleans the configurations list" do
      subject.clear_configs
      expect(subject.find_config(:system)).to be_nil
    end
  end

  describe "#add_config" do
    before { subject.main }

    it "adds the configuration to the list" do
      expect { subject.add_config(:system, system_config) }
        .to change { subject.find_config(:system) }
        .from(nil).to(system_config)
    end
  end

  describe "#read_config" do
    let(:system_config_copy) { double.as_null_object }

    before do
      subject.main
      allow(Y2Network::Config).to receive(:from).and_return(system_config)
      allow(system_config).to receive(:copy).and_return(system_config_copy)
      allow(Yast::Lan).to receive(:add_config)
    end

    it "reads the Y2Network::Config from sysconfig" do
      expect(Y2Network::Config).to receive(:from).and_return(system_config)
      subject.read_config
    end

    it "adds the read config as the Yast::Lan.system_config" do
      expect(Yast::Lan).to receive(:add_config).with(:system, system_config)
      subject.read_config
    end

    it "copies the system config as the Yast::Lan.yast_config" do
      expect(Yast::Lan).to receive(:add_config).with(:yast, system_config_copy)
      subject.read_config
    end
  end

  describe "#write_config" do
    let(:yast_config_copy) { double.as_null_object }

    before do
      subject.main
      allow(Y2Network::Config).to receive(:from).and_return(system_config)
      subject.read_config
      allow(Yast::Lan.yast_config).to receive(:write)
      allow(Yast::Lan.yast_config).to receive(:copy).and_return(yast_config_copy)
    end

    it "writes the current yast_config passing the system config as the original" do
      expect(Yast::Lan.yast_config).to receive(:write).with(original: system_config, target: nil)
      subject.write_config
    end

    it "replaces the system config by a copy of the written one" do
      expect { subject.write_config }
        .to change { Yast::Lan.system_config }
        .from(system_config).to(yast_config_copy)
    end
  end
end

describe "Yast::LanClass#writeIPv6" do
  subject { Yast::Lan }

  let(:sysctl_config) do
    instance_double(
      CFA::SysctlConfig, :conflict? => false
    ).as_null_object
  end

  before do
    allow(CFA::SysctlConfig).to receive(:new).and_return(sysctl_config)
    allow(Yast::SCR).to receive(:Execute)
      .with(path(".target.bash"), /sysctl -w/)
    allow(Yast::SCR).to receive(:Write)
      .with(path(".sysconfig.windowmanager.KDE_USE_IPV6"), String)
  end

  around do |example|
    old_ipv6 = subject.ipv6
    subject.ipv6 = ipv6
    example.run
    subject.ipv6 = old_ipv6
  end

  context "when IPv6 must be enabled" do
    let(:ipv6) { true }

    it "enables IPv6 in sysctl.conf" do
      expect(sysctl_config).to receive(:disable_ipv6=).with(false)
      expect(sysctl_config).to receive(:save)
      subject.writeIPv6
    end

    it "enables IPv6 using sysctl" do
      expect(Yast::SCR).to receive(:Execute)
        .with(path(".target.bash"), /sysctl -w net.ipv6.conf.all.disable_ipv6=0/)
      subject.writeIPv6
    end

    it "enables IPv6 for KDE" do
      expect(Yast::SCR).to receive(:Write)
        .with(path(".sysconfig.windowmanager.KDE_USE_IPV6"), "yes")
      subject.writeIPv6
    end
  end

  context "when IPv6 must be disabled" do
    let(:ipv6) { false }

    it "disables IPv6 in sysctl.conf" do
      expect(sysctl_config).to receive(:disable_ipv6=).with(true)
      expect(sysctl_config).to receive(:save)
      subject.writeIPv6
    end

    it "disables IPv6 using sysctl" do
      expect(Yast::SCR).to receive(:Execute)
        .with(path(".target.bash"), /sysctl -w net.ipv6.conf.all.disable_ipv6=1/)
      subject.writeIPv6
    end

    it "disables IPv6 for KDE" do
      expect(Yast::SCR).to receive(:Write)
        .with(path(".sysconfig.windowmanager.KDE_USE_IPV6"), "no")
      subject.writeIPv6
    end
  end
end
