#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast::UIShortcuts
include Yast::I18n
include Yast

Yast.import "LanItems"
Yast.import "Stage"

# creating a wrapper for Yast's 'header' file
$LOAD_PATH.unshift File.expand_path('../../src', __FILE__)
require "include/network/lan/udev"

class NetworkLanComplexUdev
  extend Yast::NetworkLanUdevInclude
end

describe "NetworkLanUdevInclude::update_udev_rule_key" do
  before(:each) do
    @default_rule = NetworkLanComplexUdev.GetDefaultUdevRule(
      "default1",
      "00:11:22:33:44:55"
    )
  end

  it "updates existing assignment key to new value" do
    # check if it works with assignment (=) operator
    new_name = "renamed2"

    updated_rule = NetworkLanComplexUdev.update_udev_rule_key(
      @default_rule,
      "NAME",
      new_name
    )
    expect(updated_rule).to include "NAME=\"#{new_name}\""
  end

  it "updates existing comparison key to new value" do
    # check if it works with comparison (==) operator
    new_subsystem = "hdd"

    updated_rule = NetworkLanComplexUdev.update_udev_rule_key(
      @default_rule,
      "SUBSYSTEM",
      new_subsystem
    )
    expect(updated_rule).to include "SUBSYSTEM==\"#{new_subsystem}\""
  end

  it "returns unchanged rule when key is not found" do
    expect(NetworkLanComplexUdev.update_udev_rule_key(
      @default_rule,
      "NONEXISTENT_UDEV_KEY",
      "value"
    )).to eql @default_rule
  end
end
