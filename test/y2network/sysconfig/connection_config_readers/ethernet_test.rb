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
require "y2network/sysconfig/connection_config_readers/ethernet"
require "y2network/sysconfig/interface_file"
require "y2network/boot_protocol"

describe Y2Network::Sysconfig::ConnectionConfigReaders::Ethernet do
  subject(:handler) { described_class.new(file) }

  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  around do |example|
    change_scr_root(scr_root, &example)
  end

  let(:interface_name) { "eth0" }
  let(:file) do
    Y2Network::Sysconfig::InterfaceFile.find(interface_name).tap(&:load)
  end

  describe "#connection_config" do
    it "returns an ethernet connection config object" do
      eth = handler.connection_config
      expect(eth.interface).to eq("eth0")
      expect(eth.ip.address).to eq(Y2Network::IPAddress.from_string("192.168.123.1/24"))
      expect(eth.bootproto).to eq(Y2Network::BootProtocol::STATIC)
    end

    context "when prefixlen is specified" do
      let(:interface_name) { "eth2" }

      it "uses the prefixlen as the address prefix" do
        eth = handler.connection_config
        expect(eth.ip.address).to eq(Y2Network::IPAddress.from_string("172.16.0.1/12"))
      end
    end

    context "when netmask is specified" do
      let(:interface_name) { "eth3" }

      it "uses the netmask to set the address prefix" do
        eth = handler.connection_config
        expect(eth.ip.address).to eq(Y2Network::IPAddress.from_string("10.0.0.1/8"))
      end
    end

    context "when the configuration is static" do
      before do
        Yast::Host.main
        Yast::Host.Read
      end

      context "and a hostname is specified" do
        it "sets the hostname" do
          eth = handler.connection_config
          expect(eth.hostname).to eq("foo")
        end
      end

      context "and a hostname is not specified" do
        let(:interface_name) { "eth1" }

        it "does not set the hostname" do
          eth = handler.connection_config
          expect(eth.hostname).to be_nil
        end
      end
    end

    context "when the configuration is not static" do
      let(:interface_name) { "eth4" }

      before { Yast::Host.Read }

      it "does not set the hostname" do
        eth = handler.connection_config
        expect(eth.hostname).to be_nil
      end
    end

    it "reads dhclient set hostname value as boolean" do
      expect(handler.connection_config.dhclient_set_hostname).to eq true
    end
  end
end
