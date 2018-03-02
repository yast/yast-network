#!/usr/bin/env rspec

require_relative "test_helper"
require "y2storage"

require "yast"
require "network/clients/save_network"

describe Yast::SaveNetworkClient do

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
      allow(staging).to receive(:filesystem_in_network?).and_return(in_network)
      allow(subject).to receive(:save_network)
      # Mainly for import
      subject.main
    end

    context "when installation directory is in a network device" do
      let(:in_network) { true }

      it "tunes ifcfg file for remote filesystem" do
        expect(Yast::SCR).to receive(:Execute).with(anything, /nfsroot/).once
        subject.send(:adjust_for_network_disks, file)
        expect(::File.read(file)).to include("STARTMODE=nfsroot")
      end
    end

    context "when installation directory is in a local device" do
      let(:in_network) { false }

      it "does not touch any configuration file" do
        expect(Yast::SCR).to_not receive(:Execute).with(anything, /nfsroot/)
        subject.send(:adjust_for_network_disks, file)
        expect(::File.read(file)).to eq(::File.read(template_file))
      end
    end
  end

  describe "#copy_dhcp_info" do
    let(:wicked_path) { described_class::WICKED_DHCP_PATH }
    let(:dhcpcd_path) { described_class::DHCP_CLIENT_PATH }
    let(:wicked_files) { described_class::WICKED_DHCP_FILES.map { |f| wicked_path + f } }
    let(:dhcp_client_cache) do
      described_class::DHCP_CLIENT_PATH + described_class::DHCP_CLIENT_CACHE
    end
    let(:dhcpv6_client_cache_path) { described_class::DHCPv6_CLIENT_CACHE_PATH }
    before do
      allow(Yast::Installation).to receive(:destdir).and_return("/mnt")
      allow(::FileUtils).to receive(:mkdir_p)
      allow(::FileUtils).to receive(:cp)
    end

    it "creates the wicked directory if not exist" do
      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/var/lib/wicked/")

      subject.send(:copy_dhcp_info)
    end

    it "copies the wicked dhcp files" do
      expect(::FileUtils).to receive(:cp)
        .with(wicked_files, "/mnt/var/lib/wicked/", preserve: true)

      subject.send(:copy_dhcp_info)
    end

    it "creates the dhcp client dir if not exist" do
      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/var/lib/dhcpcd/")

      subject.send(:copy_dhcp_info)
    end

    it "copies the dhcp client files" do
      expect(::FileUtils).to receive(:cp)
        .with(dhcp_client_cache, "/mnt/var/lib/dhcpcd/", preserve: true)
      expect(::FileUtils).to receive(:cp)
        .with(dhcpv6_client_cache_path, "/mnt/var/lib/dhcpv6", preserve: true)

      subject.send(:copy_dhcp_info)
    end
  end
end
