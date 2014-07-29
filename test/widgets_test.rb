#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast
include UIShortcuts
include I18n

Yast.import "LanItems"
Yast.include self, "network/widgets.rb"

describe "NetworkWidgetsInclude::ipoib_mode_widget" do

  it "contains known IPoIB modes" do
    widget_def = ipoib_mode_widget
    expect(widget_def).to include("items")

    expect(widget_def["items"]).to be_eql LanItems.ipoib_modes.to_a
  end
end
