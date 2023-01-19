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
require_relative "../../test_helper"
require "y2network/wicked/config_copier"

describe Y2Network::Wicked::ConfigCopier do
  let(:destdir) { Dir.mktmpdir }
  let(:sysconfig) { described_class::SYSCONFIG }
  let(:destdir_sysconfig) { File.join(destdir, sysconfig) }
  let(:scr_root) { File.join(DATA_PATH, "instsys") }

  before do
    stub_const("Y2Network::Helpers::ROOT_PATH", scr_root)
    allow(Yast::Installation).to receive(:destdir).and_return(destdir)
  end

  after do
    FileUtils.remove_entry(destdir) if Dir.exist?(destdir)
  end

  describe "#copy" do
    let(:template_file) { File.join(SCRStub::DATA_PATH, "ifcfg-eth0.template") }
    let(:file) { File.join(scr_root, sysconfig, "ifcfg-eth0") }

    around do |example|
      ::FileUtils.cp(template_file, file)
      example.run
      ::FileUtils.rm(file)
    end

    it "copies wicked DHCP files under /var/lib/wicked" do
      subject.copy
      expect(File).to exist(File.join(destdir, "var", "lib", "wicked", "lease.xml"))
    end

    it "copies sysconfig network files under /etc/sysconfig/network dir" do
      subject.copy
      expect(File).to exist(File.join(destdir, sysconfig, "ifcfg-eth0"))
    end
  end

  describe "#adjust_files_for_network_disks!" do
    let(:template_file) { File.join(SCRStub::DATA_PATH, "ifcfg-eth0.template") }
    let(:file) { File.join(scr_root, sysconfig, "ifcfg-eth0") }

    around do |example|
      ::FileUtils.cp(template_file, file)
      example.run
      ::FileUtils.rm(file)
    end

    before do
      Y2Storage::StorageManager.create_test_instance

      staging = Y2Storage::StorageManager.instance.staging
      allow(staging).to receive(:filesystem_in_network?).with("/").and_return(in_network)
    end

    context "when the root filesystem of the target system is in a network device" do
      let(:in_network) { true }

      it "tunes ifcfg file for remote filesystem" do
        expect(Yast::SCR).to receive(:Execute).with(anything, /nfsroot/).once
        subject.send(:adjust_files_for_network_disks!)
        expect(::File.read(file)).to include("STARTMODE=nfsroot")
      end
    end

    context "when the root filesystem of the target system is in a local device" do
      let(:in_network) { false }

      it "does not touch any configuration file" do
        expect(Yast::SCR).to_not receive(:Execute).with(anything, /nfsroot/)
        subject.send(:adjust_files_for_network_disks!)
        expect(::File.read(file)).to eq(::File.read(template_file))
      end
    end
  end
end
