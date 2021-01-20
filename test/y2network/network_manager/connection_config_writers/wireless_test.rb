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
require "y2network/network_manager/connection_config_writers/wireless"
require "cfa/nm_connection"
require "y2network/boot_protocol"
require "y2network/startmode"
require "y2network/connection_config/wireless"

describe Y2Network::NetworkManager::ConnectionConfigWriters::Wireless do
  subject(:handler) { described_class.new(file) }
  let(:file) { CFA::NmConnection.new("wlan0.nm_connection") }

  let(:conn) do
    Y2Network::ConnectionConfig::Wireless.new.tap do |c|
      c.interface = "wlan0"
      c.description = "Wireless Card 0"
      c.startmode = Y2Network::Startmode.create("auto")
      c.bootproto = Y2Network::BootProtocol::DHCP
      c.mode = "managed"
      c.essid = "example_essid"
      c.auth_mode = :open
      c.ap = "00:11:22:33:44:55"
      c.ap_scanmode = "1"
    end
  end

  describe "#write" do
    it "sets relevant attributes" do
      handler.write(conn)
      expect(file.wifi["ssid"]).to eql(conn.essid)
      expect(file.wifi["mode"]).to eql("infrastructure")
      expect(file.ipv4["method"]).to eql("auto")
      expect(file.ipv6["method"]).to eql("auto")
    end

    context "WPA-PSK network configuration" do
      let(:conn) do
        Y2Network::ConnectionConfig::Wireless.new.tap do |c|
          c.startmode = Y2Network::Startmode.create("auto")
          c.bootproto = Y2Network::BootProtocol::DHCP
          c.mode = "managed"
          c.auth_mode = "psk"
          c.wpa_psk = "example_psk"
        end
      end

      it "sets specific WPA-PSK attributes" do
        handler.write(conn)
        expect(file.wifi_security["key-mgmt"]).to eql("wpa-psk")
        expect(file.wifi_security["psk"]).to eql("example_psk")
      end
    end
  end
end
