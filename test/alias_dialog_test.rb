#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

class AliasDialog
  include Yast::I18n
  include Yast::UIShortcuts

  def initialize
    Yast.include self, "network/lan/virtual.rb"
  end
end

describe "VirtualEditDialog" do
  # bnc#864264
  it "passes smoke test" do
    include Yast::UIShortcuts

    Yast.import "UI"
    Yast.import "LanItems"

    allow(Yast::UI).to receive(:UserInput).and_return(:ok)
    allow(Yast::UI)
      .to receive(:QueryWidget)
      .and_return("")
    allow(Yast::UI)
      .to receive(:QueryWidget)
      .with(Id(:ipaddr), :Value)
      .and_return("1.1.1.1")
    allow(Yast::UI)
      .to receive(:QueryWidget)
      .with(Id(:netmask), :Value)
      .and_return("255.0.0.0")
    allow(Yast::LanItems).to receive(:device).and_return("")

    expect(Yast::UI).to receive(:UserInput).once

    new_id = 0
    existing_item = term(:empty)
    expect(AliasDialog.new.VirtualEditDialog(new_id, existing_item)).not_to be nil
  end
end
