#!/usr/bin/env rspec

# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "test_helper"

require "yast"
Yast.import "LanItems"

describe "LanItemsClass" do
  subject { Yast::LanItems }

  describe "#SetDeviceVars" do
    let(:defaults) do
      {
        "WIRELESS_KEY"   => "",
        "WIRELESS_KEY_0" => "",
        "WIRELESS_KEY_1" => "",
        "WIRELESS_KEY_2" => "",
        "WIRELESS_KEY_3" => ""
      }
    end

    it "reads value from sysconfig data" do
      subject.SetDeviceVars({ "BOOTPROTO" => "dhcp8" }, "BOOTPROTO" => "dhcp7")
      expect(subject.bootproto).to eq "dhcp8"
    end

    it "reads value from default data" do
      subject.SetDeviceVars({}, "BOOTPROTO" => "dhcp7")
      expect(subject.bootproto).to eq "dhcp7"
    end

    it "reads nil if neither hash specifies the data" do
      subject.SetDeviceVars({}, {})
      expect(subject.bootproto).to eq nil
    end

    it "converts set_default_route" do
      subject.SetDeviceVars({ "DHCLIENT_SET_DEFAULT_ROUTE" => "yes" }, defaults)
      expect(subject.set_default_route).to eq true

      subject.SetDeviceVars({ "DHCLIENT_SET_DEFAULT_ROUTE" => "no" }, defaults)
      expect(subject.set_default_route).to eq false

      subject.SetDeviceVars({}, defaults)
      expect(subject.set_default_route).to eq nil

      subject.SetDeviceVars({ "DHCLIENT_SET_DEFAULT_ROUTE" => "unrecognized" }, defaults)
      expect(subject.set_default_route).to eq nil
    end

    it "converts wl_power" do
      subject.SetDeviceVars({ "WIRELESS_POWER" => "yes" }, defaults)
      expect(subject.wl_power).to eq true
    end

    it "makes wl_key a 4-tuple when 1 key is specified" do
      subject.SetDeviceVars({ "WIRELESS_KEY" => "k0" }, defaults)
      expect(subject.wl_key).to eq ["k0", "", "", ""]
    end

    it "makes wl_key a 4-tuple when 2 keys are specified" do
      subject.SetDeviceVars({ "WIRELESS_KEY_0" => "k00", "WIRELESS_KEY_1" => "k01" }, defaults)
      expect(subject.wl_key).to eq ["k00", "k01", "", ""]
    end

    it "makes wl_wpa_eap a hash, with renamed kes" do
      subject.SetDeviceVars({
                              "WIRELESS_EAP_MODE"     => "foo",
                              "WIRELESS_PEAP_VERSION" => "bar"
                            }, {})
      expect(subject.wl_wpa_eap["WPA_EAP_MODE"]).to eq "foo"
      expect(subject.wl_wpa_eap["WPA_EAP_PEAP_VERSION"]).to eq "bar"
    end
  end

  describe "#SetS390Vars" do
    let(:defaults) { {} }

    it "converts qeth_layer2" do
      expect(Yast::Arch).to receive(:s390).and_return true

      subject.SetS390Vars({ "QETH_LAYER2" => "yes" }, defaults)
      expect(subject.qeth_layer2).to eq true
    end
  end
end
