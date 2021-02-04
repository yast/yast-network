# Copyright (c) [2021] SUSE LLC
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
require_relative "../../../support/network_manager_examples"
require "y2network/network_manager/connection_config_readers/wireless"
require "cfa/nm_connection"

describe Y2Network::NetworkManager::ConnectionConfigReaders::Wireless do
  subject(:handler) { described_class.new(file) }

  let(:file_path) { File.join(DATA_PATH, "NetworkManager", "eap.nmconnection") }

  let(:file) do
    instance_double(
      CFA::NmConnection,
      connection:    hash_to_augeas_tree({}),
      wifi:          wifi,
      ipv4:          hash_to_augeas_tree({}),
      ipv6:          hash_to_augeas_tree({}),
      wifi_security: wifi_security,
      load:          nil
    )
  end

  let(:connection) { hash_to_augeas_tree("id" => "Cable Connection") }
  let(:wifi) do
    hash_to_augeas_tree(
      "ssid" => "MYWIFI",
      "mtu"  => "1024",
      "mode" => "adhoc"
    )
  end
  let(:wifi_security) { nil }

  include_examples "NetworkManager::ConfigReader"

  describe "#connection_config" do
    before { file.load }

    it "returns a wireless connection config object" do
      wlan = handler.connection_config
      expect(wlan).to be_a(Y2Network::ConnectionConfig::Wireless)
    end

    it "sets the mtu if present" do
      wlan = handler.connection_config
      expect(wlan.mtu).to eq(1024)
    end

    it "sets the mode" do
      wlan = handler.connection_config
      expect(wlan.mode).to eq("ad-hoc")
    end

    context "when the mode is not present" do
      let(:wifi) { hash_to_augeas_tree({}) }

      it "sets it to 'managed'" do
        wlan = handler.connection_config
        expect(wlan.mode).to eq("managed")
      end
    end

    it "sets the ESSID" do
      wlan = handler.connection_config
      expect(wlan.essid).to eq("MYWIFI")
    end

    describe "EAP authentication" do
      let(:file) { CFA::NmConnection.new(file_path) }

      describe "using TLS" do
        let(:file_path) { File.join(DATA_PATH, "NetworkManager", "eap.nmconnection") }

        it "reads authentication settings" do
          wlan = handler.connection_config
          expect(wlan.auth_mode).to eq(:eap)
          expect(wlan.eap_auth).to be_nil
          expect(wlan.wpa_identity).to eq("my-identity")
          expect(wlan.ca_cert).to eq("/etc/ssl/certs/myca.pem")
          expect(wlan.client_key).to eq("/etc/ssl/private/mywifi.key")
          expect(wlan.client_key_password).to eq("12345678")
          expect(wlan.eap_mode).to eq("TLS")
        end
      end

      describe "using TTLS" do
        let(:file_path) { File.join(DATA_PATH, "NetworkManager", "eap-ttls.nmconnection") }

        it "reads authentication settings" do
          wlan = handler.connection_config
          expect(wlan.auth_mode).to eq(:eap)
          expect(wlan.eap_auth).to eq("mschapv2")
          expect(wlan.wpa_identity).to eq("user1")
          expect(wlan.wpa_anonymous_identity).to eq("my-identity")
          expect(wlan.ca_cert).to eq("/etc/ssl/certs/myca.pem")
          expect(wlan.client_key).to be_nil
          expect(wlan.client_key_password).to be_nil
          expect(wlan.eap_mode).to eq("TTLS")
        end
      end
    end

    describe "WPA-PSK authentication" do
      let(:file) { CFA::NmConnection.new(file_path) }
      let(:file_path) { File.join(DATA_PATH, "NetworkManager", "wpa.nmconnection") }

      it "reads authentication settings" do
        wlan = handler.connection_config
        expect(wlan.auth_mode).to eq(:psk)
        expect(wlan.wpa_password).to eq("12345678")
      end
    end

    describe "open WEP authentication (with ascii passwords)" do
      let(:file) { CFA::NmConnection.new(file_path) }
      let(:file_path) { File.join(DATA_PATH, "NetworkManager", "wep-open-ascii.nmconnection") }

      it "reads authentication settings" do
        wlan = handler.connection_config
        expect(wlan.auth_mode).to eq(:open)
        expect(wlan.keys).to eq(["s:12345", "s:67890"])
      end
    end

    describe "open WEP authentication (with hex passphrase)" do
      let(:file) { CFA::NmConnection.new(file_path) }
      let(:file_path) { File.join(DATA_PATH, "NetworkManager", "wep-open-128bits.nmconnection") }

      it "reads authentication settings" do
        wlan = handler.connection_config
        expect(wlan.auth_mode).to eq(:open)
        expect(wlan.keys).to eq(["h:12345", "h:67890"])
      end
    end

    describe "shared WEP authentication" do
      let(:file) { CFA::NmConnection.new(file_path) }
      let(:file_path) { File.join(DATA_PATH, "NetworkManager", "wep-shared.nmconnection") }

      it "reads authentication settings" do
        wlan = handler.connection_config
        expect(wlan.auth_mode).to eq(:shared)
        expect(wlan.keys).to eq(["s:12345", "s:67890"])
      end
    end
  end
end
