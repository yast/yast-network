#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

class RoutinesTestClass
  def initialize
    Yast.include self, "network/routines.rb"

    Yast.import "Stage"
    Yast.import "Package"
  end
end

describe "#PackagesInstall" do
  subject { RoutinesTestClass.new }

  context "when list of packages is empty" do
    it "returns :next without checking anything" do
      expect(subject.PackagesInstall([])).to eq(:next)
      expect(Yast::Package).not_to receive(:InstalledAll)
    end
  end

  context "in inst-sys" do
    it "returns :next without checking anything" do
      allow(Yast::Stage).to receive(:stage).and_return("initial")
      expect(subject.PackagesInstall(["1", "2", "3"])).to eq(:next)
      expect(Yast::Package).not_to receive(:InstalledAll)
    end
  end

  context "on a running system" do
    it "checks whether all packages are installed and returns a symbol :next or :abort" do
      allow(Yast::Stage).to receive(:stage).and_return("normal")
      expect(Yast::Package).to receive(:InstalledAll).and_return(true)
      expect(subject.PackagesInstall(["1", "2", "3"])).to eq(:next)
    end
  end
end

describe "#ValidNicName" do
  subject(:routines) { RoutinesTestClass.new }

  it "succeedes for valid names" do
    expect(routines.ValidNicName("eth0")).to be true
    expect(routines.ValidNicName("eth_0")).to be true
    expect(routines.ValidNicName("eth-0")).to be true
    expect(routines.ValidNicName("eth.0")).to be true
    expect(routines.ValidNicName("eth:0")).to be true
  end

  it "fails in case of long name" do
    expect(routines.ValidNicName("0123456789012345")). to be false
  end

  it "fails when it contains invalid character" do
    expect(routines.ValidNicName("eth0?")).to be false
  end
end

describe "#DeviceName" do
  subject(:routines) { RoutinesTestClass.new }
  let(:hwinfo) do
    {
      "sub_vendor" => "hw_vendor",
      "sub_device" => "hw_device"
    }
  end

  it "returns empty string when nothing is defined" do
    expect(routines.DeviceName({})).to be_empty
  end

  it "returns description containing model name when known" do
    expect(routines.DeviceName(hwinfo.merge("model" => "hw_model"))).to eql "hw_model"
  end

  it "returns description build from vendor and device details when model name is uknown" do
    expect(routines.DeviceName(hwinfo)).to eql "hw_vendor hw_device"
  end
end
