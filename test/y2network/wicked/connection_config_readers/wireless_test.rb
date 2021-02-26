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
require "y2network/wicked/connection_config_readers/wireless"
require "cfa/interface_file"

describe Y2Network::Wicked::ConnectionConfigReaders::Wireless do
  subject(:handler) { described_class.new(file) }

  let(:interface_name) { "wlan0" }

  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  around do |example|
    change_scr_root(scr_root, &example)
  end

  let(:file) do
    CFA::InterfaceFile.find(interface_name).tap(&:load)
  end

  context "WPA-EAP network configuration" do
    let(:interface_name) { "wlan0" }

    it "returns a wireless connection config object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets relevant attributes" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        interface:    "wlan0",
        mode:         "managed",
        essid:        "example_ssid",
        ap_scanmode:  1,
        auth_mode:    :eap,
        eap_mode:     "PEAP",
        eap_auth:     "mschapv2",
        wpa_password: "example_passwd"
      )
    end
  end

  context "WPA-PSK network configuration" do
    let(:interface_name) { "wlan1" }

    it "returns a wireless connection config object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets relevant attributes" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        interface: "wlan1",
        auth_mode: :psk,
        wpa_psk:   "example_psk",
        ap:        "00:11:22:33:44:55"
      )
    end
  end

  context "WEP network configuration" do
    let(:interface_name) { "wlan2" }

    it "returns a wireless connection config object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets relevant attributes" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        interface:   "wlan2",
        essid:       "example_ssid",
        keys:        ["0-1-2-3-4-5", "s:password", nil, nil],
        key_length:  128,
        default_key: 1
      )
    end
  end

  context "open network configuration" do
    let(:interface_name) { "wlan3" }

    it "returns a wireless connection object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets the revelant attributes" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        auth_mode: :open,
        mode:      "managed"
      )
    end
  end

  context "backward compatible auth mode" do
    let(:interface_name) { "wlan4" }

    it "sets auth mode to unified name" do
      wlan = handler.connection_config
      expect(wlan).to have_attributes(
        auth_mode: :psk
      )
    end
  end
end
