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
require "y2network/sysconfig/connection_config_writers/wireless"
require "y2network/sysconfig/interface_file"
require "y2network/connection_config/wireless"

describe Y2Network::Sysconfig::ConnectionConfigWriters::Wireless do
  subject(:handler) { described_class.new(file) }

  let(:file) { Y2Network::Sysconfig::InterfaceFile.new("wlan0") }
  let(:conn) do
    Y2Network::ConnectionConfig::Wireless.new.tap do |conn|
      conn.startmode = :auto
      conn.bootproto = :static
      conn.ip_address = address
      conn.mode = "managed"
      conn.essid = "example_essid"
      conn.auth_mode = :open
      conn.ap = "00:11:22:33:44:55"
      conn.ap_scanmode = "1"
    end
  end
  let(:address) { IPAddr.new("192.168.122.100") }

  it "sets relevant attributes" do
    handler.write(conn)
    expect(file).to have_attributes(
      startmode:            :auto,
      bootproto:            :static,
      ipaddr:               address,
      wireless_mode:        conn.mode,
      wireless_essid:       conn.essid,
      wireless_auth_mode:   :open,
      wireless_ap:          conn.ap,
      wireless_ap_scanmode: conn.ap_scanmode
    )
  end

  context "WPA-EAP network configuration" do
    let(:conn) do
      Y2Network::ConnectionConfig::Wireless.new.tap do |conn|
        conn.auth_mode = "eap"
        conn.eap_mode = "PEAP"
        conn.essid = "example_essid"
        conn.wpa_password = "example_passwd"
      end
    end

    it "sets relevant attributes" do
      handler.write(conn)
      expect(file).to have_attributes(
        wireless_auth_mode:    "eap",
        wireless_eap_mode:     "PEAP",
        wireless_essid:        "example_essid",
        wireless_wpa_password: "example_passwd"
      )
    end
  end

  context "WPA-PSK network configuration" do
    let(:conn) do
      Y2Network::ConnectionConfig::Wireless.new.tap do |conn|
        conn.auth_mode = "psk"
        conn.wpa_psk = "example_psk"
      end
    end

    it "sets relevant attributes" do
      handler.write(conn)
      expect(file).to have_attributes(
        wireless_auth_mode: "psk",
        wireless_wpa_psk:   "example_psk"
      )
    end
  end

  context "WEP network configuration" do
    let(:conn) do
      Y2Network::ConnectionConfig::Wireless.new.tap do |conn|
        conn.auth_mode = "shared"
        conn.keys = ["123456", "abcdef"]
        conn.key_length = 128
        conn.default_key = 1
      end
    end

    it "sets relevant attributes" do
      handler.write(conn)
      expect(file).to have_attributes(
        wireless_auth_mode:   "shared",
        wireless_keys:        ["123456", "abcdef"],
        wireless_key_length:  128,
        wireless_default_key: 1
      )
    end
  end
end
