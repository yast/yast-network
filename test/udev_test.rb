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

describe "NetworkLanUdevInclude#AddToUdevRule" do
  subject(:udev) { NetworkLanComplexUdev.new }

  let(:rule) { ["KERNELS=\"invalid\"", "KERNEL=\"eth*\"", "NAME=\"eth1\""] }

  it "adds new tripled into existing rule" do
    updated_rule = udev.AddToUdevRule(rule, "ENV{MODALIAS}==\"e1000\"")
    expect(updated_rule).to include "ENV{MODALIAS}==\"e1000\""
  end
end

describe "NetworkLanUdevInclude#RemoveKeyFromUdevRule" do
  subject(:udev) { NetworkLanComplexUdev.new }

  let(:rule) { ["KERNELS=\"invalid\"", "KERNEL=\"eth*\"", "NAME=\"eth1\""] }

  it "removes tripled from existing rule" do
    updated_rule = udev.RemoveKeyFromUdevRule(rule, "KERNEL")
    expect(updated_rule).not_to include "KERNEL=\"eth*\""
  end
end

describe "LanItems#ReplaceItemUdev" do
  Yast.import "LanItems"

  before(:each) do
    Yast::LanItems.current = 0

    # LanItems should create "udev" and "net" subkeys for each item
    # during Read
    allow(Yast::LanItems)
      .to receive(:Items)
      .and_return(0 => { "udev" => {"net" => [] } })
  end

  it "replaces triplet in the rule as requested" do
    allow(Yast::LanItems)
      .to receive(:getUdevFallback)
      .and_return(
        [
          "KERNELS==\"invalid\"",
          "KERNEL=\"eth*\"",
          "NAME=\"eth1\""
        ]
      )

    expect(Yast::LanItems).to receive(:SetModified)

    updated_rule = Yast::LanItems.ReplaceItemUdev(
      "KERNELS",
      "ATTR{address}",
      "xx:01:02:03:04:05"
    )
    expect(updated_rule).to include "ATTR{address}==\"xx:01:02:03:04:05\""
  end

  it "do not set modification flag in case of no change" do
    allow(Yast::LanItems)
      .to receive(:getUdevFallback)
      .and_return(
        [
          "ATTR{address}==\"xx:01:02:03:04:05\"",
          "KERNEL=\"eth*\"",
          "NAME=\"eth1\""
        ]
      )

      Yast::LanItems.ReplaceItemUdev(
        "KERNELS",
        "ATTR{address}",
        "xx:01:02:03:04:05"
      )

    expect(Yast::LanItems).not_to receive(:SetModified)
  end
end
