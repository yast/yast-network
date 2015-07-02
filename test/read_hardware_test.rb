#! /usr/bin/env rspec

require "yast"

require_relative "netcard_probe_helper"

describe "#ReadHardware" do
  def storage_only_devices
    devices = probe_netcard.select { |n| n["storageonly"] }
    devices.map { |d| d["dev_name"] }
  end

  def path(p)
    Yast::Path.new(p)
  end

  # testsuite for bnc#841170
  it "excludes storage only devices" do
    Yast.include self, "network/routines.rb"

    allow(Yast::SCR).to receive(:Read).and_return(nil)
    allow(Yast::SCR).to receive(:Read).with(path(".probe.netcard")) { probe_netcard }

    read_storage_devices = ReadHardware("netcard").select do |d|
      storage_only_devices.include? d["dev_name"]
    end

    expect(read_storage_devices).to be_empty
  end
end
