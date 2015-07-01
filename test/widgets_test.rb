#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast::UIShortcuts
include Yast::I18n

Yast.import "LanItems"

class WidgetsTestClass
  def initialize
    Yast.include self, "network/widgets.rb"
  end
end

describe "NetworkWidgetsInclude::ipoib_mode_widget" do
  subject { WidgetsTestClass.new }

  it "contains known IPoIB modes" do
    widget_def = subject.ipoib_mode_widget
    expect(widget_def).to include("items")

    expect(widget_def["items"]).to be_eql Yast::LanItems.ipoib_modes.to_a
  end
end
