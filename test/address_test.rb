#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "UI"

class DummyClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/address.rb"
  end
end

describe "NetworkLanAddressInclude" do
  subject { DummyClass.new }

  describe "#justify_dev_name" do

    it "returns given device name justified by 0's at right" do
      expect(subject.justify_dev_name("em5p1")).to eq("em00005p00001")
    end

  end

  describe "devices_to_s" do
    subject(:routines) { DummyClass.new }
    let(:devices) do
      [ "eth0", "eth1", "eth2", "eth3", "a_very_long_device_name" ]
    end
    let(:more_devices) do
      [
        "enp5s0", "enp5s1", "enp5s2", "enp5s3",
        "enp5s4", "enp5s5", "enp5s6", "enp5s7"
      ]
    end

    context "given a list of devices" do
      it "returns given devices joined by a space" do
        text = "eth0 eth1 eth2 eth3 a_very_long_device_name"

        expect(routines.devices_to_s(devices)).to eql(text)
      end

      context "given a line size" do
        it "returns given devices wrapped by line size" do
          text = "eth0 eth1 eth2\n"         \
                 "eth3\n"                   \
                 "a_very_long_device_name"

          expect(routines.devices_to_s(devices, 15)).to eql(text)
        end
      end

      context "given a number of lines and '...' as cut text" do
        it "returns wrapped text until given line adding '...' as a new line" do
          text = "eth0 eth1 eth2\n"         \
                 "eth3\n"                   \
                 "a_very_long_device_name\n"  \
                 "..."

          expect(routines.devices_to_s(devices+more_devices, 15,3,"...")).to eql(text)
        end
      end

    end
  end

  describe "#getISlaveIndex" do
    let(:msbox_items) do
      [
        Yast::Term.new(:item, Yast::Term.new(:id, "eth0")),
        Yast::Term.new(:item, Yast::Term.new(:id, "eth1")),
        Yast::Term.new(:item, Yast::Term.new(:id, "eth1.5")),
        Yast::Term.new(:item, Yast::Term.new(:id, "eth2"))
      ]
    end

    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(:msbox_items, :Items) { msbox_items }
    end

    it "returns the index position of the given slave in the mbox_items table" do
      expect(subject.getISlaveIndex("eth2")).to eql(3)
      expect(subject.getISlaveIndex("eth1.5")).to eql(2)
    end

    it "returns -1 in case the slave is not in the msbox_items table" do
      expect(subject.getISlaveIndex("eth4")).to eql(-1)
    end
  end

  describe "#ValidateBond" do
    let(:msbox_items) do
      ["eth0", "eth1", "eth2", "eth3", "eth4", "eth5", "eth6", "eth7",
       "enp0sp25", "enp0sp26", "enp0sp27", "enp0sp28", "enp0sp29"]
    end

    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(:msbox_items, :SelectedItems) { msbox_items }

    end

    context "when there is not more than one physical port id per interface" do
      let(:msbox_items) do
        ["eth0", "eth1", "eth2", "eth3"]
      end

      before do
        allow(Yast::UI).to receive(:QueryWidget)
          .with(:msbox_items, :SelectedItems) { msbox_items }
        allow(subject).to receive(:has_physical_id?).with("eth0") { false }
        allow(subject).to receive(:has_physical_id?).with("eth1") { false }
        allow(subject).to receive(:has_physical_id?).with("eth2") { true }
        allow(subject).to receive(:has_physical_id?).with("eth3") { true }
        allow(subject).to receive(:has_physical_id).with("eth2") { "00010486fd348" }
        allow(subject).to receive(:has_physical_id).with("eth3") { "00010486fd34a" }
      end

      it "returns true" do
        expect(subject.ValidateBond("key", "Event")).to eql(true)
      end
    end

    context "when there is more than one physical port id per interface" do
      before do
        ["eth0", "eth1", "eth2", "eth3", "eth4", "eth5", "eth6", "eth7",
         "enp0sp25", "enp0sp26", "enp0sp27", "enp0sp28", "enp0sp29"].map do |i|
          allow(subject).to receive(:has_physical_port_id?).with(i) { true }
          allow(subject).to receive(:physical_port_id).with(i) { "00010486fd348" }
        end
      end

      it "warns the user and request confirmation for continue" do
        expect(Yast::Popup).to receive(:YesNoHeadline) { :request_answer }

        expect(subject.ValidateBond("key", "Event")).to eql(:request_answer)
      end
    end
  end

end
