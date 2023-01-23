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
require "y2network/backends"
require "network/clients/save_network"
require "tmpdir"

Yast.import "Installation"
Yast.import "DNS"

describe Yast::SaveNetworkClient do
  describe "#main" do
    let(:destdir) { Dir.mktmpdir }
    let(:destdir_sysconfig) { File.join(destdir, "etc", "sysconfig", "network") }
    let(:scr_root) { File.join(DATA_PATH, "instsys") }
    let(:yast_config) { Y2Network::Config.new(source: :wicked, backend: system_backend) }
    let(:system_config) do
      Y2Network::Config.new(source: :wicked, backend: system_backend)
    end
    let(:system_backend) { Y2Network::Backends::Wicked.new }
    let(:s390) { false }
    let(:propose_bridge) { false }
    let(:selected_backend) { :wicked }

    before do
      stub_const("Y2Network::Helpers::ROOT_PATH", scr_root)
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)
      allow(Yast::Package).to receive(:Installed).and_return(false)

      FileUtils.mkdir_p(destdir_sysconfig)
      ["dhcp", "config"].each do |file|
        FileUtils.cp(File.join(DATA_PATH, "#{file}.original"), File.join(destdir_sysconfig, file))
      end

      allow(Y2Network::ProposalSettings.instance).to receive(:network_service)
        .and_return(selected_backend)
      allow(Y2Network::ProposalSettings.instance).to receive(:virt_bridge_proposal)
        .and_return(propose_bridge)
      allow(Yast::NetworkAutoconfiguration.instance).to receive(:configure_dns)
      allow(Yast::NetworkAutoconfiguration.instance).to receive(:configure_hosts)
      allow(Yast::NetworkAutoconfiguration.instance).to receive(:configure_routing)
      allow(Yast::Lan).to receive(:yast_config).and_return(yast_config)
      allow(Yast::Lan).to receive(:system_config).and_return(system_config)
      allow(Yast::Lan).to receive(:write_config)
      allow(Yast::Lan).to receive(:Write)
      allow(Yast::Arch).to receive(:s390).and_return(s390)
      allow(Yast::NetworkService).to receive(:EnableDisableNow)
      allow(Yast::NetworkService).to receive(:disable_service)
      allow(Yast::NetworkAutoYast.instance).to receive(:configure_hosts).and_return(nil)
    end

    after do
      FileUtils.remove_entry(destdir) if Dir.exist?(destdir)
    end

    it "copies /etc/sysctl.d/70-yast.conf config when it exists" do
      subject.main
      expect(File).to exist(File.join(destdir, "etc", "sysctl.d", "70-yast.conf"))
    end

    it "copies /etc/hostname and /etc/hosts when exist" do
      subject.main
      expect(File).to_not exist(File.join(destdir, "etc", "hosts"))
      content = File.read(File.join(destdir, "etc", "hostname"))
      expect(content).to match(/test/)
    end

    it "copies wicked and DHCP files under /var/lib" do
      subject.main
      expect(File).to exist(File.join(destdir, "var", "lib", "dhcp", "dhclient.leases"))
      expect(File).to exist(File.join(destdir, "var", "lib", "wicked", "lease.xml"))
    end

    it "copies udev rules" do
      subject.main
      content = File.read(File.join(destdir, "etc", "udev", "rules.d", "70-persistent-net.rules"))
      expect(content).to match(/00:11:22:33:44:55/)
    end

    context "when running in s390" do
      let(:s390) { true }

      it "copies udev rules to 41-*" do
        subject.main
        content = File.read(File.join(destdir, "etc", "udev", "rules.d", "41-persistent-net.rules"))
        expect(content).to match(/55:44:33:22:11:00/)
      end
    end

    it "ensures that the network configuration changes are written but not applied" do
      Yast::Lan.write_only = false

      expect { subject.main }.to change { Yast::Lan.write_only }.from(false).to(true)
    end

    it "merges netconfig configuration" do
      subject.main

      config_file = CFA::GenericSysconfig.new(
        File.join(destdir, "etc", "sysconfig", "network", "config")
      )
      config_file.load

      expect(config_file.attributes["NETCONFIG_DNS_POLICY"])
        .to eq("eth0")
      expect(config_file.attributes["LINK_REQUIRED"])
        .to eq("auto")
    end

    it "merges DHCP configuration" do
      subject.main

      dhcp_file = CFA::GenericSysconfig.new(
        File.join(destdir, "etc", "sysconfig", "network", "dhcp")
      )
      dhcp_file.load

      expect(dhcp_file.attributes["DHCLIENT_FQDN_ENABLED"]).to eq("enabled")
      expect(dhcp_file.attributes["DHCLIENT_SET_HOSTNAME"]).to eq("no")
    end

    context "when virtualization bridge network config proposal is wanted" do
      let(:propose_bridge) { true }

      it "configures the network according to the proposal" do
        expect(subject).to receive(:propose_virt_config?).and_return(propose_bridge)
        expect(Yast::NetworkAutoconfiguration.instance).to receive(:configure_virtuals)

        subject.main
      end
    end

    context "during autoinstallation" do
      let(:ay_hosts) { true }
      let(:selected_backend) { :network_manager }

      before do
        allow(Yast::Mode).to receive(:autoinst).and_return(true)
        allow(Yast::NetworkAutoYast.instance).to receive(:configure_hosts).and_return(ay_hosts)
      end

      it "will select the backend according to the profile or the confirm dialog if modified" do
        expect { subject.main }
          .to change { yast_config.backend&.id }.from(:wicked).to(:network_manager)
      end

      it "configures the network according the already imported configuration" do
        expect(Yast::NetworkAutoYast.instance).to receive(:configure_lan)
        subject.main
      end

      it "does not automatically configure the DNS" do
        expect(Yast::NetworkAutoconfiguration.instance).to_not receive(:configure_dns)
        subject.main
      end

      it "configures the /etc/hosts according to the profile" do
        expect(Yast::NetworkAutoYast.instance).to receive(:configure_hosts)
        subject.main
      end

      context "if the hosts are not configured by AutoYaST" do
        it "configures the /etc/hosts automatically" do
          allow(Yast::NetworkAutoYast.instance).to receive(:configure_hosts).and_return(false)
          expect(Yast::NetworkAutoconfiguration.instance).to receive(:configure_hosts)
          subject.main
        end
      end
    end

    context "in case of not written previously" do
      it "configures dns, hosts and routing according to the proposal" do
        expect(Yast::NetworkAutoconfiguration.instance).to receive(:configure_dns)
        expect(Yast::NetworkAutoconfiguration.instance).to receive(:configure_routing)
        expect(Yast::NetworkAutoconfiguration.instance).to receive(:configure_hosts)
        subject.main
      end
    end

    context "when the backend is network manager" do
      let(:selected_backend) { :network_manager }

      before do
        FileUtils.mkdir_p(File.join(destdir, "etc", "NetworkManager", "system-connections"))
      end

      it "writes the configuration to the underlying system" do
        expect(Yast::Lan).to receive(:write_config)
        subject.main
      end

      it "disables wicked" do
        expect(Yast::NetworkService).to receive(:disable_service).with(:wicked)

        subject.main
      end

      context "when running on network manager (e.g., live installation)" do
        let(:system_backend) { Y2Network::Backends::NetworkManager.new }

        it "copies the NetworkManager configuration from the instsys" do
          expect(Yast::Lan).to_not receive(:write_config)
          subject.main
          expect(File).to exist(
            File.join(destdir, "etc", "NetworkManager", "system-connections", "wlan0.nmconnection")
          )
        end

        it "selects NetworkManager as the service to be used after installation" do
          expect(Yast::NetworkService).to receive(:use_network_manager)
          subject.main
        end

        it "enables the selected service in the target system" do
          expect(Yast::NetworkService).to receive(:EnableDisableNow)
          subject.main
        end
      end
    end

    context "when the backend selected is wicked" do
      let(:selected_backend) { :wicked }

      it "disables NetworkManager" do
        expect(Yast::NetworkService).to receive(:disable_service).with(:network_manager)

        subject.main
      end

      it "selects wicked as the service to be used after installation" do
        expect(Yast::NetworkService).to receive(:use_wicked)
        subject.main
      end

      it "enables the selected service in the target system" do
        expect(Yast::NetworkService).to receive(:EnableDisableNow)
        subject.main
      end
    end

    context "when it is selected to disable the network services" do
      let(:selected_backend) { :none }

      it "disables wicked and NetworkManager services" do
        expect(Yast::NetworkService).to receive(:disable_service).with(:wicked)
        expect(Yast::NetworkService).to receive(:disable_service).with(:network_manager)

        subject.main
      end
    end

    context "during update" do
      before do
        allow(Yast::Mode).to receive(:update).and_return(true)
      end

      it "does not modify the network" do
        expect(subject).to_not receive(:save_network)
        subject.main
      end
    end
  end
end
