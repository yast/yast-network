#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"
Yast.import "Stage"

# mock class only for testing include
class NetworkLanComplexUdev < Yast::Module
  def initialize
    Yast.include self, "network/lan/udev"
  end
end

describe "NetworkLanUdevInclude#update_udev_rule_key" do
  subject { NetworkLanComplexUdev.new }

  let(:default_rule) do
    subject.GetDefaultUdevRule("default1", "00:11:22:33:44:55")
  end

  it "updates existing assignment key to new value" do
    new_name = "renamed2"

    updated_rule = subject.update_udev_rule_key(
      default_rule,
      "NAME",
      new_name
    )
    expect(updated_rule).to include "NAME=\"#{new_name}\""
  end

  it "updates existing comparison key to new value" do
    new_subsystem = "hdd"

    updated_rule = subject.update_udev_rule_key(
      default_rule,
      "SUBSYSTEM",
      new_subsystem
    )
    expect(updated_rule).to include "SUBSYSTEM==\"#{new_subsystem}\""
  end

  it "returns unchanged rule when key is not found" do
    updated_rule = subject.update_udev_rule_key(
      default_rule,
      "NONEXISTENT_UDEV_KEY",
      "value"
    )
    expect(updated_rule).to eq default_rule
  end
end

describe "#udev_rule_key" do
  let(:rule) { ["KERNELS==\"invalid\"", "KERNEL==\"eth*\"", "NAME=\"eth1\""] }

  it "raises ArgumentError if given rule is empty" do
    expect { Yast::LanItems.udev_key_value(nil, "KERNEL") }
      .to raise_error(ArgumentError, "Rule must not be nil when querying a key value")
  end

  it "returns value of the first attribute which matches given key" do
    expect(Yast::LanItems.udev_key_value(rule, "KERNEL")).to eql("eth*")
  end

  it "returns an empty string if no rule matches" do
    expect(Yast::LanItems.udev_key_value(rule, "ATTR{address}")).to eql("")
  end
end

describe "NetworkLanUdevInclude#AddToUdevRule" do
  subject(:udev) { NetworkLanComplexUdev.new }

  let(:rule) { ["KERNELS==\"invalid\"", "KERNEL==\"eth*\"", "NAME=\"eth1\""] }

  it "adds new tripled into existing rule" do
    updated_rule = udev.AddToUdevRule(rule, "ENV{MODALIAS}==\"e1000\"")
    expect(updated_rule).to include "ENV{MODALIAS}==\"e1000\""
  end
end

describe "NetworkLanUdevInclude#RemoveKeyFromUdevRule" do
  subject(:udev) { NetworkLanComplexUdev.new }

  let(:rule) { ["KERNELS==\"invalid\"", "KERNEL==\"eth*\"", "NAME=\"eth1\""] }

  it "removes tripled from existing rule" do
    updated_rule = udev.RemoveKeyFromUdevRule(rule, "KERNEL")
    expect(updated_rule).not_to include "KERNEL=\"eth*\""
  end
end

describe "LanItems#ReplaceItemUdev" do
  let(:rule) { [] }
  let(:items) { { 0 => { "udev" => { "net" => rule } } } }
  let(:mac_address) { "xx:01:02:03:04:05" }

  before(:each) do
    Yast::LanItems.current = 0

    # LanItems should create "udev" and "net" subkeys for each item
    # during Read
    allow(Yast::LanItems).to receive(:Items).and_return(items)
  end

  context "when the given Item hasn't got an udev rule" do
    let(:items) { { 0 => {} } }
    let(:default_rule) { Yast::LanItems.GetDefaultUdevRule("eth1", mac_address) }

    it "creates and assings a new rule for the given Item" do
      allow(Yast::LanItems).to receive(:getUdevFallback).and_return(default_rule)

      expect(Yast::LanItems).to receive(:SetModified)

      updated_rule = Yast::LanItems.ReplaceItemUdev("KERNELS", "ATTR{address}", mac_address)
      item_rule    = Yast::LanItems.getCurrentItem["udev"]["net"]

      expect(updated_rule).to include "ATTR{address}==\"#{mac_address}\""
      expect(item_rule).to include "ATTR{address}==\"#{mac_address}\""
    end
  end

  context "when the given Item has got an udev rule" do
    let(:rule) { ["ATTR==\"#{mac_address}\"", "KERNEL==\"eth*\"", "NAME=\"eth1\""] }
    let(:bus_id) { "0000:08:00.0" }

    it "replaces triplet in the rule as requested" do
      expect(Yast::LanItems).to receive(:SetModified)

      updated_rule = Yast::LanItems.ReplaceItemUdev("ATTR{address}", "KERNELS", bus_id)
      item_rule    = Yast::LanItems.getCurrentItem["udev"]["net"]

      expect(updated_rule).to include "KERNELS==\"#{bus_id}\""
      expect(updated_rule).not_to include "ATTR{address}==\"#{mac_address}\""
      expect(item_rule).to include "KERNELS==\"#{bus_id}\""
      expect(item_rule).not_to include "ATTR{address}==\"#{mac_address}\""
    end

    it "does not set modification flag in case of no change" do
      Yast::LanItems.ReplaceItemUdev("ATTR{address}", "ATTR{address}", mac_address)

      expect(Yast::LanItems).not_to receive(:SetModified)
    end

    # this is an SCR limitation
    it "contains NAME tuplet at last position" do
      updated_rule = Yast::LanItems.ReplaceItemUdev("ATTR{address}", "KERNELS", bus_id)

      expect(updated_rule.last).to match(/NAME.*/)
    end
  end
end
