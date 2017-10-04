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
        subject.adjust_for_network_disks(file)
        expect(::File.read(file)).to include("STARTMODE=nfsroot")
      end
    end

    context "when installation directory is in a local device" do
      let(:in_network) { false }

      it "does not touch any configuration file" do
        expect(Yast::SCR).to_not receive(:Execute).with(anything, /nfsroot/)
        subject.adjust_for_network_disks(file)
        expect(::File.read(file)).to eq(::File.read(template_file))
      end
    end
  end
end
