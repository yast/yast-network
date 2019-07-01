#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

class RoutinesTestClass
  include Yast::UIShortcuts

  def initialize
    Yast.import "Stage"
    Yast.import "Package"

    Yast.include self, "network/routines.rb"
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

  it "fails for empty string" do
    expect(routines.ValidNicName("")).to be false
  end

  it "fails for newline terminated string" do
    expect(routines.ValidNicName("eth0\n")).to be false
  end
end

describe "#DeviceName" do
  subject(:routines) { RoutinesTestClass.new }
  let(:hwinfo_details) do
    {
      "sub_vendor" => "hw_vendor",
      "sub_device" => "hw_device"
    }
  end
  let(:hwinfo_generic) do
    {
      "vendor" => "vendor"
    }
  end
  let(:hwinfo) { hwinfo_generic.merge(hwinfo_details) }

  it "returns empty string when nothing is defined" do
    expect(routines.DeviceName({})).to be_empty
  end

  it "returns description containing model name when known" do
    expect(routines.DeviceName(hwinfo.merge("model" => "hw_model"))).to eql "hw_model"
  end

  it "returns description build from vendor and device details when model name is uknown" do
    expect(routines.DeviceName(hwinfo)).to eql "hw_vendor hw_device"
  end

  it "uses vendor for building description when no detailed information is known" do
    expect(routines.DeviceName(hwinfo_generic)).to eql "vendor"
  end
end

describe "physical_port_id" do
  subject(:routines) { RoutinesTestClass.new }
  let(:phys_port_id) { "physical_port_id" }

  before do
    allow(Yast::SCR).to receive(:Read)
      .with(Yast::Path.new(".target.string"), "/sys/class/net/eth0/phys_port_id")
      .and_return(phys_port_id)
  end

  context "when the module driver support it" do
    it "returns ethernet physical port id" do
      expect(routines.physical_port_id("eth0")).to eql("physical_port_id")
    end
  end

  context "when the module driver doesn't support it" do
    let(:phys_port_id) { nil }

    it "returns an empty string" do
      expect(routines.physical_port_id("eth0")).to be_empty
    end
  end
end

describe "#physical_port_id?" do
  subject(:routines) { RoutinesTestClass.new }

  it "returns true if physical port id is not empty" do
    allow(routines).to receive(:physical_port_id).with("eth0") { "physical_port_id" }

    expect(routines.physical_port_id?("eth0")).to eql(true)
  end
end
