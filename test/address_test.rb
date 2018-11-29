#!/usr/bin/env rspec

require_relative "test_helper"

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
      allow(Yast::UI).to receive(:QueryWidget).with(:msbox_items, :Items).and_return(msbox_items)
    end

    it "returns the index position of the given slave in the mbox_items table" do
      expect(subject.getISlaveIndex("eth2")).to eql(3)
      expect(subject.getISlaveIndex("eth1.5")).to eql(2)
    end

    it "returns -1 in case the slave is not in the msbox_items table" do
      expect(subject.getISlaveIndex("eth4")).to eql(-1)
    end
  end

  describe "#validate_bond" do
    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(:msbox_items, :SelectedItems)
        .and_return(msbox_items)
    end

    context "when there is not more than one physical port id per interface" do
      let(:msbox_items) { ["eth0", "eth1", "eth2", "eth3"] }

      it "returns true" do
        allow(subject).to receive(:physical_port_id?).with("eth0").and_return(false)
        allow(subject).to receive(:physical_port_id?).with("eth1").and_return(false)
        allow(subject).to receive(:physical_port_id?).with("eth2").and_return(true)
        allow(subject).to receive(:physical_port_id?).with("eth3").and_return(true)
        allow(subject).to receive(:physical_port_id).with("eth2").and_return("00010486fd348")
        allow(subject).to receive(:physical_port_id).with("eth3").and_return("00010486fd34a")

        expect(subject.validate_bond("key", "Event")).to eql(true)
      end
    end

    context "when there is more than one physical port id per interface" do
      let(:msbox_items) do
        ["eth0", "eth1", "eth2", "eth3", "eth4", "eth5", "eth6", "eth7",
         "enp0sp25", "enp0sp26", "enp0sp27", "enp0sp28", "enp0sp29"]
      end

      it "warns the user and request confirmation to continue" do
        msbox_items.map do |i|
          allow(subject).to receive(:physical_port_id?).with(i).and_return(true)
          allow(subject).to receive(:physical_port_id).with(i).and_return("00010486fd348")
        end

        expect(Yast::Popup).to receive(:YesNoHeadline).and_return(:request_answer)

        expect(subject.validate_bond("key", "Event")).to eql(:request_answer)
      end
    end
  end

  describe "#update_hostname" do
    let(:ip) { "1.1.1.1" }
    let(:initial_hostname) { "initial.hostname.com" }
    let(:new_hostname) { "new.hostname.com" }

    before(:each) do
      allow(Yast::LanItems)
        .to receive(:ipaddr)
        .and_return(ip)
      allow(subject)
        .to receive(:initial_hostname)
        .and_return(initial_hostname)
      allow(Yast::Host)
        .to receive(:names)
        .and_call_original
      allow(Yast::Host)
        .to receive(:names)
        .with(ip)
        .and_return(["#{initial_hostname} custom-name"])
    end

    it "drops old /etc/hosts record if hostname was changed" do
      expect(Yast::Host)
        .to receive(:remove_ip)
        .with(ip)
      expect(Yast::Host)
        .to receive(:Update)
        .with(initial_hostname, new_hostname, ip)

      subject.send(:update_hostname, ip, new_hostname)
    end

    it "keeps names untouched when only the ip was changed" do
      new_ip = "2.2.2.2"

      original_names = Yast::Host.names(ip)
      subject.send(:update_hostname, new_ip, initial_hostname)

      expect(Yast::Host.names(new_ip)).to eql original_names
    end
  end

end
