#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.include self, "network/routines.rb"

Yast.import "Stage"
Yast.import "Package"

describe "#PackagesInstall" do
  context "when list of packages is empty" do
    it "returns :next without checking anything" do
      expect(PackagesInstall([])).to eq(:next)
      expect(Yast::Package).not_to receive(:InstalledAll)
    end
  end

  context "in inst-sys" do
    it "returns :next without checking anything" do
      allow(Yast::Stage).to receive(:stage).and_return("initial")
      expect(PackagesInstall(["1", "2", "3"])).to eq(:next)
      expect(Yast::Package).not_to receive(:InstalledAll)
    end
  end

  context "on a running system" do
    it "checks whether all packages are installed and returns a symbol :next or :abort" do
      allow(Yast::Stage).to receive(:stage).and_return("normal")
      expect(Yast::Package).to receive(:InstalledAll).and_return(true)
      expect(PackagesInstall(["1", "2", "3"])).to eq(:next)
    end
  end
end
