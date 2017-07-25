#!/usr/bin/env rspec

require_relative "test_helper"
require "y2storage"

require "yast"
require "network/clients/save_network"
describe Yast::SaveNetworkClient do
  describe "#adjust_for_network_disks" do
    before do
      Y2Storage::StorageManager.create_test_instance

      staging = Y2Storage::StorageManager.instance.staging
      allow(staging).to receive(:filesystem_in_network?).and_return(in_network)
      allow(Yast::SCR).to receive(:Execute).and_return("exit" => 0, "stdout" => "", "stderr" => "")
    end

    context "when installation directory is in a network device" do
      let(:in_network) { true }

      it "tunes ifcfg file for remote filesystem" do
        expect(Yast::SCR).to receive(:Execute).with(anything, /nfsroot/).once
        subject.main
      end
    end

    context "when installation directory is in a local device" do
      let(:in_network) { false }

      it "does not touch any configuration file" do
        expect(Yast::SCR).to_not receive(:Execute).with(anything, /nfsroot/)
        subject.main
      end
    end
  end
end
