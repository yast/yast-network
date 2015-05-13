#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"
Yast.import "Stage"

# mock class only for testing include
class NetworkLanComplexUdev
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
