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
require "y2storage"

require "yast"
require "y2network/config"
require "network/clients/save_network"
require "tmpdir"

Yast.import "Installation"

describe Yast::SaveNetworkClient do
  describe "#main" do
    let(:destdir) { Dir.mktmpdir }
    let(:destdir_sysconfig) { File.join(destdir, "etc", "sysconfig", "network") }
    let(:scr_root) { File.join(DATA_PATH, "instsys") }
    let(:yast_config) { Y2Network::Config.new(source: :sysconfig) }
    let(:system_config) { Y2Network::Config.new(source: :sysconfig) }
    let(:s390) { false }

    before do
      stub_const("Yast::SaveNetworkClient::ROOT_PATH", scr_root)
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)

      FileUtils.mkdir_p(destdir_sysconfig)
      ["dhcp", "config"].each do |file|
        FileUtils.cp(File.join(DATA_PATH, "#{file}.original"), File.join(destdir_sysconfig, file))
      end

      allow(Yast::NetworkAutoconfiguration.instance).to receive(:configure_dns)
      allow(Yast::Lan).to receive(:yast_config).and_return(yast_config)
      allow(Yast::Lan).to receive(:system_config).and_return(system_config)
      allow(Yast::Lan).to receive(:write_config)
      allow(Yast::Lan).to receive(:Write)
      allow(Yast::Arch).to receive(:s390).and_return(s390)
      allow(Yast::NetworkService).to receive(:EnableDisableNow)
    end

    after do
      FileUtils.remove_entry(destdir) if Dir.exist?(destdir)
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

    context "when virtualization support is installed" do
      before do
        allow(Yast::PackageSystem).to receive(:Installed).and_return(false)
        allow(Yast::PackageSystem).to receive(:Installed).with("kvm").and_return(true)
      end

      it "proposes virtual interfaces configuration" do
        expect(Yast::Lan).to receive(:ProposeVirtualized)
        subject.main
      end
    end

    context "during autoinstallation" do
      before do
        allow(Yast::Mode).to receive(:autoinst).and_return(true)
      end

      it "does not automatically configure the DNS" do
        expect(Yast::NetworkAutoconfiguration.instance).to_not receive(:configure_dns)
        subject.main
      end
    end

    context "when the backend is network manager" do
      before do
        allow(Y2Network::ProposalSettings.instance).to receive(:network_service)
          .and_return(:network_manager)
        FileUtils.mkdir_p(File.join(destdir, "etc", "NetworkManager", "system-connections"))
      end

      it "writes the configuration to the underlying system" do
        expect(Yast::Lan).to receive(:write_config)
        subject.main
      end

      context "on live installation" do
        before do
          allow(Yast::Mode).to receive(:live_installation).and_return(true)
        end

        it "copies the NetworkManager configuration from the instsys" do
          expect(Yast::Lan).to_not receive(:write_config)
          subject.main
          expect(File).to exist(
            File.join(destdir, "etc", "NetworkManager", "system-connections", "wlan0.nmconnection")
          )
        end
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

  describe "#adjust_for_network_disks" do
    let(:template_file) { File.join(SCRStub::DATA_PATH, "ifcfg-eth0.template") }
    let(:file) { File.join(SCRStub::DATA_PATH, "ifcfg-eth0") }

    around do |example|
      ::FileUtils.cp(template_file, file)
      example.run
      ::FileUtils.rm(file)
    end

    before do
      Y2Storage::StorageManager.create_test_instance

      staging = Y2Storage::StorageManager.instance.staging
      allow(staging).to receive(:filesystem_in_network?).with("/").and_return(in_network)
      allow(subject).to receive(:save_network)
      # Mainly for import
      subject.main
    end

    context "when the root filesystem of the target system is in a network device" do
      let(:in_network) { true }

      it "tunes ifcfg file for remote filesystem" do
        expect(Yast::SCR).to receive(:Execute).with(anything, /nfsroot/).once
        subject.send(:adjust_for_network_disks, file)
        expect(::File.read(file)).to include("STARTMODE=nfsroot")
      end
    end

    context "when the root filesystem of the target system is in a local device" do
      let(:in_network) { false }

      it "does not touch any configuration file" do
        expect(Yast::SCR).to_not receive(:Execute).with(anything, /nfsroot/)
        subject.send(:adjust_for_network_disks, file)
        expect(::File.read(file)).to eq(::File.read(template_file))
      end
    end
  end
end
