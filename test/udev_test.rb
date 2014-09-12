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
  it "updates specified udev rule's key to the new value" do
    default_rule = NetworkLanComplexUdev.GetDefaultUdevRule(
      "default1", "00:11:22:33:44:55"
    )
    new_name = "renamed2"

    updated_rule = NetworkLanComplexUdev.update_udev_rule_key(
      default_rule,
      "NAME",
      new_name
    )
    expect(updated_rule.any? { |i| i =~ /NAME.*#{new_name}/ })
      .to be true
  end
end
