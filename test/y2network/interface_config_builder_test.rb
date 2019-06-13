#!/usr/bin/env rspec

require_relative "../test_helper"

require "yast"
require "y2network/interface_config_builder"

describe Y2Network::InterfaceConfigBuilder do
  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilder.new
    res.type = "eth"
    res.name = "eth0"
    res
  end

  describe ".for" do
    context "specialized class for given type exists" do
      it "returns new instance of that class" do
        expect(described_class.for("ib").class.to_s).to eq "Y2Network::InterfaceConfigBuilders::Ib"
      end
    end

    context "specialized class for given type does NOT exist" do
      it "returns instance of InterfaceConfigBuilder" do
        expect(described_class.for("dummy").class).to eq described_class
      end

      it "sets type to passed type" do
        expect(described_class.for("dummy").type).to eq "dummy"
      end
    end
  end

  describe ".save" do
    around do |block|
      Yast::LanItems.AddNew
      # FIXME: workaround for device without reading hwinfo, so udev is not initialized
      Yast::LanItems.Items[Yast::LanItems.current]["udev"] = {}
      block.call
      Yast::LanItems.Rollback
    end

    it "stores driver configuration" do
      subject.driver = "e1000e"
      subject.driver_options = "test"
      subject.save
      expect(Yast::LanItems.Items[Yast::LanItems.current]["udev"]["driver"]).to eq "e1000e"
      expect(Yast::LanItems.driver_options["e1000e"]).to eq "test"
    end

    it "stores aliases" do
      subject.aliases = [{ ip: "10.0.0.0", prefixlen: "24", label: "test", mask: "" }]
      subject.save
      expect(Yast::LanItems.aliases).to eq(
        0 => { "IPADDR" => "10.0.0.0", "LABEL" => "test", "PREFIXLEN" => "24", "NETMASK" => "" }
      )
    end
  end

  describe "#new_device_startmode" do
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

          result = config_builder.device_sysconfig["STARTMODE"]
          expect(result).to be_eql "auto"
        end
      end

      context "When product_startmode is ifplugd and device " + hotplug_desc do
        before(:each) do
          expect(Yast::ProductFeatures)
            .to receive(:GetStringFeature)
              .with("network", "startmode") { "ifplugd" }
          allow(config_builder).to receive(:hotplug_interface?) { hwinfo_hotplug == "hotplug" }
          # setup stubs by default at results which doesn't need special handling
          allow(Yast::Arch).to receive(:is_laptop) { true }
          allow(Yast::NetworkService).to receive(:is_network_manager) { false }
        end

        it "results to #{expected_startmode} when not running on laptop" do
          expect(Yast::Arch)
            .to receive(:is_laptop) { false }

          result = config_builder.device_sysconfig["STARTMODE"]
          expect(result).to be_eql expected_startmode
        end

        it "results to ifplugd when running on laptop" do
          expect(Yast::Arch)
            .to receive(:is_laptop) { true }

          result = config_builder.device_sysconfig["STARTMODE"]
          expect(result).to be_eql "ifplugd"
        end

        it "results to #{expected_startmode} when running NetworkManager" do
          expect(Yast::NetworkService)
            .to receive(:is_network_manager) { true }

          result = config_builder.device_sysconfig["STARTMODE"]
          expect(result).to be_eql expected_startmode
        end

        it "results to #{expected_startmode} when current device is virtual one" do
          # check for virtual device type is done via Builtins.contains. I don't
          # want to stub it because it requires default stub value definition for
          # other calls of the function. It might have unexpected inpacts.
          allow(config_builder).to receive(:type) { "bond" }

          result = config_builder.device_sysconfig["STARTMODE"]
          expect(result).to be_eql expected_startmode
        end
      end

      context "When product_startmode is not auto neither ifplugd" do
        AVAILABLE_PRODUCT_STARTMODES.each do |product_startmode|
          it "for #{product_startmode} it results to #{expected_startmode} if device " + hotplug_desc do
            expect(Yast::ProductFeatures)
              .to receive(:GetStringFeature)
                .with("network", "startmode") { product_startmode }
            expect(config_builder)
              .to receive(:hotplug_interface?) { hwinfo_hotplug == "hotplug" }

            result = config_builder.device_sysconfig["STARTMODE"]
            expect(result).to be_eql expected_startmode
          end
        end
      end
    end
  end
end
