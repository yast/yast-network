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

require_relative "../../../test_helper"
require "y2network/sysconfig/connection_config_readers/wlan"
require "y2network/sysconfig/interface_file"

describe Y2Network::Sysconfig::ConnectionConfigReaders::Wlan do
  subject(:handler) { described_class.new(file) }

  let(:address) { IPAddr.new("192.168.122.1") }

  let(:file) do
    instance_double(
      Y2Network::Sysconfig::InterfaceFile,
      interface:            "wlan0",
      name:                 "Wireless Card 0",
      startmode:            :auto,
      bootproto:            :static,
      ip_address:           address,
      wireless_keys:        ["0-1-2-3-4-5", "s:password"],
      wireless_default_key: 1,
      wireless_key_length:  128
    ).as_null_object
  end

  context "WPA-EAP network configuration" do
    let(:file) do
      instance_double(
        Y2Network::Sysconfig::InterfaceFile,
        interface:             "wlan0",
        name:                  "Wireless Card 0",
        bootproto:             :static,
        ip_address:            address,
        wireless_auth_mode:    "eap",
        wireless_eap_mode:     "PEAP",
        wireless_eap_auth:     "mschapv2",
        wireless_essid:        "example_ssid",
        wireless_mode:         "Managed",
        wireless_wpa_password: "example_passwd",
        wireless_ap_scanmode:  "1"
      ).as_null_object
    end

    it "returns a wireless connection config object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets relevant attributes" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        interface:    "wlan0",
        mode:         "Managed",
        essid:        "example_ssid",
        ap_scanmode:  "1",
        auth_mode:    "eap",
        eap_mode:     "PEAP",
        eap_auth:     "mschapv2",
        wpa_password: "example_passwd"
      )
    end
  end

  context "WPA-PSK network configuration" do
    let(:wireless_attributes) do
      COMMON_PARAMETERS.merge(
        "WIRELESS_AP"        => "00:11:22:33:44:55",
        "WIRELESS_AUTH_MODE" => "psk",
        "WIRELESS_ESSID"     => "example_ssid",
        "WIRELESS_WPA_PSK"   => "example_psk"
      )
    end
    let(:file) do
      instance_double(
        Y2Network::Sysconfig::InterfaceFile,
        interface:          "wlan0",
        name:               "Wireless Card 0",
        bootproto:          :static,
        wireless_ap:        "00:11:22:33:44:55",
        wireless_auth_mode: "psk",
        wireless_wpa_psk:   "example_psk"
      ).as_null_object
    end

    it "returns a wireless connection config object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets relevant attributes" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        interface: "wlan0",
        auth_mode: "psk",
        wpa_psk:   "example_psk",
        ap:        "00:11:22:33:44:55"
      )
    end
  end

  context "WEP network configuration" do
    let(:file) do
      instance_double(
        Y2Network::Sysconfig::InterfaceFile,
        interface:            "wlan0",
        name:                 "Wireless Card 0",
        bootproto:            :static,
        ip_address:           address,
        wireless_auth_mode:   "shared",
        wireless_essid:       "example_ssid",
        wireless_keys:        ["0-1-2-3-4-5", "s:password"],
        wireless_key_length:  128,
        wireless_default_key: 1
      ).as_null_object
    end

    it "returns a wireless connection config object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets relevant attributes" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        interface:   "wlan0",
        essid:       "example_ssid",
        keys:        ["0-1-2-3-4-5", "s:password"],
        key_length:  128,
        default_key: 1
      )
    end
  end

  context "open network configuration" do
    let(:file) do
      instance_double(
        Y2Network::Sysconfig::InterfaceFile,
        interface:          "wlan0",
        name:               "Wireless Card 0",
        wireless_auth_mode: :open,
        wireless_mode:      :managed
      ).as_null_object
    end

    it "returns a wireless connection object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets the revelant attributes" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        auth_mode: :open,
        mode:      :managed
      )
    end
  end
end
