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
      c.ap_scanmode = 1
    end
  end

  describe "#write" do
    it "sets device and IP relevant attributes" do
      handler.write(conn)
      expect(file.wifi["ssid"]).to eql(conn.essid)
      expect(file.wifi["mode"]).to eql("infrastructure")
      expect(file.ipv4["method"]).to eql("auto")
      expect(file.ipv6["method"]).to eql("auto")
    end

    context "when configuring without encryption" do
      it "does not set any authentication" do
        handler.write(conn)
        expect(file.wifi_security["auth-alg"]).to be(nil)
      end
    end

    context "when configuring with WEP authentication (open or shared)" do
      let(:conn) do
        Y2Network::ConnectionConfig::Wireless.new.tap do |c|
          c.startmode = Y2Network::Startmode.create("auto")
          c.bootproto = Y2Network::BootProtocol::STATIC
          c.mode = "managed"
          c.auth_mode = "shared"
          c.keys = ["123456", "s:abcdef"]
          c.key_length = 128
          c.default_key = 1
        end
      end

      it "sets specific WEP wireless security attributes" do
        handler.write(conn)
        expect(file.wifi_security["auth-alg"]).to eql("shared")
        expect(file.wifi_security["wep-tx-keyidx"]).to eql("1")
        expect(file.wifi_security["wep-key1"]).to eql("abcdef")
        expect(file.wifi_security["wep-key-type"]).to eql("1")
        conn.auth_mode = :open
        handler.write(conn)
        expect(file.wifi_security["auth-alg"]).to eql("open")
      end
    end

    context "when configuring with WPA-PSK authentication" do
      let(:conn) do
        Y2Network::ConnectionConfig::Wireless.new.tap do |c|
          c.startmode = Y2Network::Startmode.create("auto")
          c.bootproto = Y2Network::BootProtocol::DHCP
          c.mode = "managed"
          c.auth_mode = "psk"
          c.wpa_psk = "example_psk"
        end
      end

      it "sets specific WPA-PSK wireless security attributes" do
        handler.write(conn)
        expect(file.wifi_security["key-mgmt"]).to eql("wpa-psk")
        expect(file.wifi_security["psk"]).to eql("example_psk")
      end
    end

    context "when configuring with WPA-EAP authentication" do
      let(:server_cert) { "/etc/raddb/certs/server.crt" }
      let(:client_cert) { "/etc/raddb/certs/client.crt" }
      let(:client_key) { "/etc/raddb/certs/client.key" }
      let(:client_key_password) { "whatever" }
      let(:eap_mode) { "PEAP" }
      let(:section_802_1x) { file.section_for("802-1x") }

      let(:conn) do
        Y2Network::ConnectionConfig::Wireless.new.tap do |c|
          c.startmode = Y2Network::Startmode.create("auto")
          c.bootproto = Y2Network::BootProtocol::DHCP
          c.mode = "managed"
          c.auth_mode = "eap"
          c.eap_mode = eap_mode
          c.wpa_identity = "user@example.com"
          c.wpa_password = "testing123"
          c.wpa_anonymous_identity = "anonymous@example.com"
        end
      end

      it "sets specific WPA-EAP wireless security attributes" do
        handler.write(conn)
        expect(file.wifi_security["key-mgmt"]).to eql("wpa-eap")
        expect(section_802_1x["eap"]).to_not be_nil
      end

      context "using PEAP eap mode" do
        it "sets the the eap mode to 'peap'" do
          handler.write(conn)
          expect(section_802_1x["eap"]).to eql("peap")
        end

        it "sets the identity and password" do
          handler.write(conn)
          expect(section_802_1x["identity"]).to eql("user@example.com")
          expect(section_802_1x["password"]).to eql("testing123")
        end

        context "when defined a server certificate" do
          it "sets it" do
            conn.ca_cert = server_cert
            handler.write(conn)
            expect(section_802_1x["ca-cert"]).to eql(server_cert)
          end
        end
      end

      context "using TLS eap mode" do
        let(:eap_mode) { "TLS" }
        before do
          conn.client_key = client_key
          conn.client_key_password = client_key_password
          conn.client_cert = client_cert
          conn.ca_cert = server_cert
        end

        it "sets the the eap mode to 'tls'" do
          handler.write(conn)
          expect(section_802_1x["eap"]).to eql("tls")
        end

        it "sets the identity" do
          handler.write(conn)
          expect(section_802_1x["identity"]).to eql("user@example.com")
        end

        it "sets the client key, client key password and client certificate" do
          handler.write(conn)
          expect(section_802_1x["client-cert"]).to eql(client_cert)
          expect(section_802_1x["private-key"]).to eql(client_key)
          expect(section_802_1x["private-key-password"]).to eql(client_key_password)
        end

        context "when defined a server certificate" do
          it "sets it" do
            conn.ca_cert = server_cert
            handler.write(conn)
            expect(section_802_1x["ca-cert"]).to eql(server_cert)
          end
        end
      end

      context "using TTLS eap mode" do
        let(:eap_mode) { "TTLS" }

        before do
          conn.ca_cert = server_cert
        end

        it "sets the the eap mode to 'tls'" do
          handler.write(conn)
          expect(section_802_1x["eap"]).to eql("ttls")
        end

        it "sets the identity, anonymous identity and password" do
          handler.write(conn)
          expect(section_802_1x["identity"]).to eql("user@example.com")
          expect(section_802_1x["anonymous-identity"]).to eql("anonymous@example.com")
          expect(section_802_1x["password"]).to eql("testing123")
        end

        context "when defined a server certificate" do
          it "sets it" do
            conn.ca_cert = server_cert
            handler.write(conn)
            expect(section_802_1x["ca-cert"]).to eql(server_cert)
          end
        end
      end
    end
  end
end
