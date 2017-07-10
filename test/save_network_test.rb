#!/usr/bin/env rspec

require_relative "test_helper"
require "y2storage"

require "yast"
require "network/clients/save_network"
describe Yast::SaveNetworkClient do
  describe "#adjust_for_network_disks" do
    before do
    allow(Yast::SCR).to receive(:Execute).and_return("exit" => 0, "stdout" => "", "stderr" => "")
    fake_scenario(scenario)
    end
    let(:scenario) { "mixed_disks" }

    context "when installation directory is in a network device" do
      before do
        allow(Y2Storage::StorageManager.instance).to receive(:y2storage_staging).and_return(fake_devicegraph)
        allow(fake_devicegraph).to receive(:filesystem_in_network?).and_return(true)
      end

      it "tunes ifcfg file for remote filesystem" do
        expect(Yast::SCR).to receive(:Execute).with(anything, /nfsroot/).once
        subject.main
      end
    end

    context "when installation directory is in a local device" do
      before do
        allow(Y2Storage::StorageManager.instance).to receive(:y2storage_staging).and_return(fake_devicegraph)
        allow(fake_devicegraph).to receive(:filesystem_in_network?).and_return(false)
      end

      it "does not touch any configuration file" do
        expect(Yast::SCR).to_not receive(:Execute).with(anything, /nfsroot/)
        subject.main
      end
    end
  end
end
