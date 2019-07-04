#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "ProductFeatures"
Yast.import "LanItems"

describe "LanItemsClass#new_device_startmode" do
  before do
    allow(Yast::ProductFeatures).to receive(:GetStringFeature)
    allow(Yast::LanItems).to receive(:type) { "eth" }
  end

  DEVMAP_STARTMODE_INVALID = {
    "STARTMODE" => "invalid"
  }.freeze

  AVAILABLE_PRODUCT_STARTMODES = [
    "hotplug",
    "manual",
    "off",
    "nfsroot"
  ].freeze

  ["hotplug", ""].each do |hwinfo_hotplug|
    expected_startmode = hwinfo_hotplug == "hotplug" ? "hotplug" : "auto"
    hotplug_desc = hwinfo_hotplug == "hotplug" ? "can hotplug" : "cannot hotplug"

    context "When product_startmode is auto and device " + hotplug_desc do
      it "results to auto" do
        expect(Yast::ProductFeatures)
          .to receive(:GetStringFeature)
            .with("network", "startmode") { "auto" }

        result = Yast::LanItems.new_device_startmode
        expect(result).to be_eql "auto"
      end
    end

    context "When product_startmode is ifplugd and device " + hotplug_desc do
      before(:each) do
        expect(Yast::ProductFeatures)
          .to receive(:GetStringFeature)
            .with("network", "startmode") { "ifplugd" }
        allow(Yast::LanItems).to receive(:hotplug_usable?) { hwinfo_hotplug == "hotplug" }
        # setup stubs by default at results which doesn't need special handling
        allow(Yast::Arch).to receive(:is_laptop) { true }
        allow(Yast::NetworkService).to receive(:is_network_manager) { false }
      end

      it "results to #{expected_startmode} when not running on laptop" do
        expect(Yast::Arch)
          .to receive(:is_laptop) { false }

        result = Yast::LanItems.new_device_startmode
        expect(result).to be_eql expected_startmode
      end

      it "results to #{expected_startmode} when running NetworkManager" do
        expect(Yast::NetworkService)
          .to receive(:is_network_manager) { true }

        result = Yast::LanItems.new_device_startmode
        expect(result).to be_eql expected_startmode
      end

      it "results to #{expected_startmode} when current device is virtual one" do
        # check for virtual device type is done via Builtins.contains. I don't
        # want to stub it because it requires default stub value definition for
        # other calls of the function. It might have unexpected inpacts.
        allow(Yast::LanItems).to receive(:type) { "bond" }

        result = Yast::LanItems.new_device_startmode
        expect(result).to be_eql expected_startmode
      end

      context "and running on a laptop without NetworkManager" do
        it "returns ifplugd is the device is not a virtual one" do
          expect(Yast::Arch)
            .to receive(:is_laptop) { true }
          allow(Yast::NetworkService)
            .to receive(:is_network_manager) { false }

          result = Yast::LanItems.new_device_startmode
          expect(result).to be_eql "ifplugd"
        end
      end
    end

    context "When product_startmode is not auto neither ifplugd" do
      AVAILABLE_PRODUCT_STARTMODES.each do |product_startmode|
        it "for #{product_startmode} it results to #{expected_startmode} if device " + hotplug_desc do
          expect(Yast::ProductFeatures)
            .to receive(:GetStringFeature)
              .with("network", "startmode") { product_startmode }
          expect(Yast::LanItems)
            .to receive(:hotplug_usable?) { hwinfo_hotplug == "hotplug" }

          result = Yast::LanItems.new_device_startmode
          expect(result).to be_eql expected_startmode
        end
      end
    end
  end
end
