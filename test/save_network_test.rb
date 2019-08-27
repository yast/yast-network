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

  describe "#copy_dhcp_info" do
    let(:wicked_path) { described_class::WICKED_DHCP_PATH }
    let(:dhcpv4_path) { described_class::DHCPv4_PATH }
    let(:dhcpv6_path) { described_class::DHCPv6_PATH }
    let(:wicked_files) do
      described_class::WICKED_DHCP_FILES.map { |f| File.join(wicked_path, f) }
    end
    let(:dhcpv4_files) { described_class::DHCP_FILES.map { |f| File.join(dhcpv4_path, f) } }
    let(:dhcpv6_files) { described_class::DHCP_FILES.map { |f| File.join(dhcpv6_path, f) } }
    before do
      allow(Yast::Installation).to receive(:destdir).and_return("/mnt")
      allow(::FileUtils).to receive(:mkdir_p)
      allow(::FileUtils).to receive(:cp)
      allow(::Dir).to receive(:glob).with(wicked_files).and_return(["1.xml", "2.xml"])
      allow(::Dir).to receive(:glob).with(dhcpv4_files).and_return(["3.leases"])
      allow(::Dir).to receive(:glob).with(dhcpv6_files).and_return(["4.leases"])
    end

    it "creates the wicked directory if not exist" do
      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/var/lib/wicked/")

      subject.send(:copy_dhcp_info)
    end

    it "copies the wicked dhcp files" do
      expect(::FileUtils).to receive(:cp)
        .with(["1.xml", "2.xml"], "/mnt/var/lib/wicked/", preserve: true)

      subject.send(:copy_dhcp_info)
    end

    it "creates the dhcp client dirs if not exist" do
      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/var/lib/dhcp/")
      expect(::FileUtils).to receive(:mkdir_p).with("/mnt/var/lib/dhcp6/")

      subject.send(:copy_dhcp_info)
    end

    it "copies the dhcp client files" do
      expect(::FileUtils).to receive(:cp)
        .with(["3.leases"], "/mnt/var/lib/dhcp/", preserve: true)
      expect(::FileUtils).to receive(:cp)
        .with(["4.leases"], "/mnt/var/lib/dhcp6/", preserve: true)

      subject.send(:copy_dhcp_info)
    end
  end
end
