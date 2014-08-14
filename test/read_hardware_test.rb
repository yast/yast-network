#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

include Yast

require_relative 'factories/probe_netcard'

Yast.include self, "network/routines.rb"

describe "#ReadHardware" do
  # testsuite for bnc#841170
  it "excludes storage only devices" do
    ordinary_nic     = probe_netcard_factory(0)
    storage_only_nic = probe_netcard_factory(1).merge("storageonly" => true)

    allow(Yast::Arch).to receive(:architecture).and_return "x86_64"
    allow(Yast::Confirm).to receive(:Detection).and_return true
    expect(Yast::SCR).
      to receive(:Read).
      with(Yast::Path.new(".etc.install_inf.BrokenModules")).
      and_return ""

    expect(Yast::SCR).
      to receive(:Read).
      with(path(".probe.netcard")).
      and_return [ordinary_nic, storage_only_nic]

    expect(ReadHardware("netcard")).to have(1).items
  end
end
