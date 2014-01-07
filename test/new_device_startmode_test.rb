#!rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "ProductFeatures"
Yast.import "LanItems"

describe "#startmode_for_product" do

  DEVMAP_STARTMODE_INVALID = {
    "STARTMODE" => "invalid"
  }

  context "When product_startmode is auto" do

    it "results to auto" do
      expect(Yast::ProductFeatures)
        .to receive(:GetStringFeature)
        .with("network", "startmode") { "auto" }

      devmap = Yast::deep_copy( DEVMAP_STARTMODE_INVALID)
      result_devmap = Yast::LanItems.startmode_for_product(devmap)
      expect(result_devmap).to include("STARTMODE" => "auto")
    end
  end

  ["hotplug", ""].each do |hwinfo_hotplug|

    expected_startmode = hwinfo_hotplug == "hotplug" ? "hotplug" : "auto"
    hotplug_desc = hwinfo_hotplug == "hotplug" ? "can hotplug" : "cannot hotplug"

    context "When product_startmode is ifplugd and device " + hotplug_desc do

      before( :each) do
        expect(Yast::ProductFeatures)
          .to receive(:GetStringFeature)
          .with("network", "startmode") { "ifplugd" }
        Yast::Ops.stub(:get_string) { hwinfo_hotplug }
        # setup stubs by default at results which doesn't need special handling
        Yast::Arch.stub(:is_laptop) { true }
        Yast::NetworkService.stub(:is_network_manager) { false }
      end

      it "results to #{expected_startmode} when not running on laptop" do
        expect(Yast::Arch)
          .to receive(:is_laptop) { false }

        devmap = Yast::deep_copy( DEVMAP_STARTMODE_INVALID)
        result_devmap = Yast::LanItems.startmode_for_product(devmap)
        expect(result_devmap).to include("STARTMODE" => expected_startmode)
      end

      it "results to ifplugd when running on laptop" do
        expect(Yast::Arch)
          .to receive(:is_laptop) { true }

        devmap = Yast::deep_copy( DEVMAP_STARTMODE_INVALID)
        result_devmap = Yast::LanItems.startmode_for_product(devmap)
        expect(result_devmap).to include("STARTMODE" => "ifplugd")
      end

      it "results to #{expected_startmode} when running NetworkManager" do
        expect(Yast::NetworkService)
          .to receive(:is_network_manager) { true }

        devmap = Yast::deep_copy( DEVMAP_STARTMODE_INVALID)
        result_devmap = Yast::LanItems.startmode_for_product(devmap)
        expect(result_devmap).to include("STARTMODE" => expected_startmode)
      end

      it "results to #{expected_startmode} when current device is virtual one" do
        # check for virtual device type is done via Builtins.contains. I don't
        # want to stub it because it requires default stub value definition for
        # other calls of the function. It might have unexpected inpacts.
        Yast::LanItems.stub(:type) { "bond" }

        devmap = Yast::deep_copy( DEVMAP_STARTMODE_INVALID)
        result_devmap = Yast::LanItems.startmode_for_product(devmap)
        expect(result_devmap).to include("STARTMODE" => expected_startmode)
      end
    end

    context "When product_startmode is not auto neither ifplugd" do

      AVAILABLE_PRODUCT_STARTMODES = [
        "hotplug",
        "manual",
        "off",
        "nfsroot"
      ]

      AVAILABLE_PRODUCT_STARTMODES.each do |product_startmode|

        # defaults are set elsewhere currently in such case
        it "for #{product_startmode} it does nothing if device " + hotplug_desc do
          expect(Yast::ProductFeatures)
            .to receive(:GetStringFeature)
            .with("network", "startmode") { product_startmode }

          Yast::Builtins.y2milestone( "Failing test ... ")
          Yast::Builtins.y2milestone( "#{DEVMAP_STARTMODE_INVALID}")

          devmap = Yast::deep_copy( DEVMAP_STARTMODE_INVALID)
          result_devmap = Yast::LanItems.startmode_for_product(devmap)
          expect(result_devmap).to be_eql DEVMAP_STARTMODE_INVALID

          Yast::Builtins.y2milestone( "#{result_devmap}")
        end
      end
    end
  end
end
