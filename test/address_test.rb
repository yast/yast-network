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

end
