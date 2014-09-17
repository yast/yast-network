#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
Yast.import "LanItems"

describe "LanItemsClass" do
  subject(:li) { Yast::LanItems }

  describe "#SetDeviceVars" do
    let(:defaults) do
      {
        "WIRELESS_KEY" => "",
        "WIRELESS_KEY_0" => "",
        "WIRELESS_KEY_1" => "",
        "WIRELESS_KEY_2" => "",
        "WIRELESS_KEY_3" => ""
      }
    end

    it "reads value from sysconfig data" do
      li.SetDeviceVars({"BOOTPROTO" => "dhcp8"}, {"BOOTPROTO" => "dhcp7"})
      expect(li.bootproto).to eq "dhcp8"
    end

    it "reads value from default data" do
      li.SetDeviceVars({}, {"BOOTPROTO" => "dhcp7"})
      expect(li.bootproto).to eq "dhcp7"
    end

    it "reads nil if neither hash specifies the data" do
      li.SetDeviceVars({}, {})
      expect(li.bootproto).to eq nil
    end

    it "converts set_default_route" do
      li.SetDeviceVars({"DHCLIENT_SET_DEFAULT_ROUTE" => "yes"}, defaults)
      expect(li.set_default_route).to eq true

      li.SetDeviceVars({"DHCLIENT_SET_DEFAULT_ROUTE" => "no"}, defaults)
      expect(li.set_default_route).to eq false

      li.SetDeviceVars({}, defaults)
      expect(li.set_default_route).to eq nil

      li.SetDeviceVars({"DHCLIENT_SET_DEFAULT_ROUTE" => "unrecognized"}, defaults)
      expect(li.set_default_route).to eq nil
    end

    it "converts wl_power" do
      li.SetDeviceVars({"WIRELESS_POWER" => "yes"}, defaults)
      expect(li.wl_power).to eq true
    end

    it "makes wl_key a 4-tuple when 1 key is specified" do
      li.SetDeviceVars({"WIRELESS_KEY" => "k0"}, defaults)
      expect(li.wl_key).to eq ["k0", "", "", ""]
    end

    it "makes wl_key a 4-tuple when 2 keys are specified" do
      li.SetDeviceVars({"WIRELESS_KEY_0" => "k00", "WIRELESS_KEY_1" => "k01"}, defaults)
      expect(li.wl_key).to eq ["k00", "k01", "", ""]
    end

    it "makes wl_wpa_eap a hash, with renamed kes" do
      li.SetDeviceVars({
                         "WIRELESS_EAP_MODE"     => "foo",
                         "WIRELESS_PEAP_VERSION" => "bar"
                       }, {})
      expect(li.wl_wpa_eap["WPA_EAP_MODE"]).to eq "foo"
      expect(li.wl_wpa_eap["WPA_EAP_PEAP_VERSION"]).to eq "bar"
    end
  end

  describe "#SetS390Vars" do
    let(:defaults) { { } }

    it "converts qeth_layer2" do
      expect(Yast::Arch).to receive(:s390).and_return true

      li.SetS390Vars({"QETH_LAYER2" => "yes"}, defaults)
      expect(li.qeth_layer2).to eq true
    end

  end
end
