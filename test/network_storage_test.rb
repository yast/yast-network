#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "NetworkStorage"

describe Yast::NetworkStorage do
  describe ".getDevices" do
    let(:data_dir) { File.join(File.dirname(__FILE__), "data") }

    around do |example|
      change_scr_root(File.join(data_dir, "scr_root"), &example)
    end

    it "skips the rootfs entry when mount point is /" do
      expect(Yast::NetworkStorage.getDevice("/")).to eql("/dev/sda2")
    end

    it "returns nfs when mount point is nfs or nfs4" do
      expect(Yast::NetworkStorage.getDevice("/home")).to eql("nfs")
      expect(Yast::NetworkStorage.getDevice("/dat")).to eql("nfs")
    end

    it "returns the device when mount point is not nfs and not rootfs" do
      expect(Yast::NetworkStorage.getDevice("/opt")).to eql("/dev/mapper/system-opt")
    end

    it "returns an empty string when mount point does not exist" do
      expect(Yast::NetworkStorage.getDevice("/var")).to eql("")
    end
  end
end
