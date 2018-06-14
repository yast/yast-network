#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"

class WidgetsTestClass < Yast::Module
  def initialize
    Yast.include self, "network/widgets.rb"
  end
end

describe "NetworkWidgetsInclude::ipoib_mode_widget" do
  subject { WidgetsTestClass.new }

  it "contains known IPoIB modes" do
    widget_def = subject.ipoib_mode_widget
    expect(widget_def).to include("items")

    Yast::LanItems.ipoib_modes.to_a.each do |item|
      expect(widget_def["items"]).to include(item)
    end
  end
end
