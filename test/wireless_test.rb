#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "LanItems"

class WirelessTestClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/wireless.rb"
  end
end

describe "WirelessInclude" do
  subject { WirelessTestClass.new }

  describe "#InitPeapVersion" do
    before do
      allow(Yast::UI).to receive(:ChangeWidget)
    end

    it "Enables widget if WPA_EAP_MODE is PEAP" do
      Yast::LanItems.wl_wpa_eap["WPA_EAP_MODE"] = "PEAP"
      expect(Yast::UI).to receive(:ChangeWidget).with(Id("test"), :Enabled, true)

      subject.InitPeapVersion("test")
    end
  end
end
