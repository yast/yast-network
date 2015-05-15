#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/network_autoyast"

describe "NetworkAutoyYast" do
  describe "#merge_devices" do
    it "returns empty result when both maps are empty"
    it "returns empty result when both maps are nil"
    it "returns other map when one map is empty"
    it "merges nonempty maps with no collisions in keys"
    it "merges nonempty maps including maps referenced by colliding key"
  end
end
