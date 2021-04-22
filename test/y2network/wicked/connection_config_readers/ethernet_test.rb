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
require "y2network/wicked/connection_config_readers/ethernet"
require "cfa/interface_file"
require "y2network/boot_protocol"
require "y2issues"

describe Y2Network::Wicked::ConnectionConfigReaders::Ethernet do
  subject(:handler) { described_class.new(file, issues_list) }

  let(:issues_list) { Y2Issues::List.new }
  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  before do
    allow(Yast::Host).to receive(:load_hosts).and_call_original
  end

  around do |example|
    change_scr_root(scr_root, &example)
  end

  let(:interface_name) { "eth0" }
  let(:file) do
    CFA::InterfaceFile.find(interface_name).tap(&:load)
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
          expect(eth.hostname).to eq("foo.example.com")
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

    context "when the BOOTPROTO is not valid" do
      before do
        allow(file).to receive(:bootproto).and_return("something")
      end

      context "and there is some defined address" do

        before do
          allow(file).to receive(:ipaddrs).and_return([double("IP")])
        end

        it "falls back to STATIC" do
          eth = handler.connection_config
          expect(eth.bootproto).to eq(Y2Network::BootProtocol::STATIC)
        end

        it "registers an issue" do
          handler.connection_config
          issue = issues_list.first
          expect(issue.location.to_s).to eq(
            "file:/etc/sysconfig/network/ifcfg-eth0:BOOTPROTO"
          )
          expect(issue.message).to include("Invalid value 'something'")
        end
      end

      context "and there are not defined addresses" do
        before do
          allow(file).to receive(:ipaddrs).and_return([])
        end

        it "falls back to DHCP" do
          eth = handler.connection_config
          expect(eth.bootproto).to eq(Y2Network::BootProtocol::DHCP)
        end

        it "registers an issue" do
          handler.connection_config
          issue = issues_list.first
          expect(issue.location.to_s).to eq(
            "file:/etc/sysconfig/network/ifcfg-eth0:BOOTPROTO"
          )
          expect(issue.message).to include("Invalid value 'something'")
        end
      end
    end

    context "when the STARTMODE is not valid" do
      before do
        allow(file).to receive(:startmode).and_return("automatic")
      end

      it "falls back to MANUAL" do
        eth = handler.connection_config
        expect(eth.startmode.to_s).to eq("manual")
      end

      it "registers an issue" do
        handler.connection_config
        issue = issues_list.first
        expect(issue.location.to_s).to eq(
          "file:/etc/sysconfig/network/ifcfg-eth0:STARTMODE"
        )
        expect(issue.message).to include("Invalid value 'automatic'")
      end
    end
  end
end
