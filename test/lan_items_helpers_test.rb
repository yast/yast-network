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

require "y2network/config"
require "y2network/interface"
require "y2network/routing"
require "y2network/route"
require "y2network/routing_table"

describe "#ifaces_dhcp_ntp_servers" do
  let(:config) do
    instance_double("Y2Network::Config", connections: connections)
  end

  let(:conn_eth0) do
    instance_double(
      Y2Network::ConnectionConfig::Base,
      interface: "eth0",
      dhcp?:     true
    )
  end

  let(:conn_eth1) do
    instance_double(
      Y2Network::ConnectionConfig::Base,
      interface: "eth1",
      dhcp?:     true
    )
  end

  let(:connections) do
    Y2Network::ConnectionConfigsCollection.new([conn_eth0, conn_eth1])
  end

  result = {
    "eth0" => ["1.0.0.1"],
    "eth1" => ["1.0.0.2", "1.0.0.3"]
  }

  before(:each) do
    allow(Yast::Lan).to receive(:yast_config).and_return(config)
  end

  it "lists ntp servers for every device which provides them" do
    allow(Yast::Lan)
      .to receive(:parse_ntp_servers)
      .and_return([])
    allow(Yast::Lan)
      .to receive(:parse_ntp_servers)
      .with("eth0")
      .and_return(["1.0.0.1"])
    allow(Yast::Lan)
      .to receive(:parse_ntp_servers)
      .with("eth1")
      .and_return(["1.0.0.2", "1.0.0.3"])

    expect(Yast::Lan.ifaces_dhcp_ntp_servers).to eql result
  end
end

context "when handling DHCLIENT_SET_HOSTNAME configuration" do
  let(:config) do
    instance_double("Y2Network::Config", connections: connections, hostname: hostname)
  end

  let(:conn_yes) do
    instance_double(
      Y2Network::ConnectionConfig::Base,
      interface:             "eth0",
      dhclient_set_hostname: "yes"
    )
  end

  let(:conn_no) do
    instance_double(
      Y2Network::ConnectionConfig::Base,
      interface:             "eth1",
      dhclient_set_hostname: "no"
    )
  end

  let(:conn_undef) do
    instance_double(
      Y2Network::ConnectionConfig::Base,
      interface:             "eth1",
      dhclient_set_hostname: nil
    )
  end

  let(:connections) do
    Y2Network::ConnectionConfigsCollection.new([conn_yes, conn_no, conn_undef])
  end

  let(:hostname) { nil }

  before(:each) do
    allow(Yast::Lan).to receive(:Read)
    allow(Yast::Lan).to receive(:yast_config).and_return(config)
  end

  describe "#find_set_hostname_ifaces" do
    context "when any configuration has DHCLIENT_SET_HOSTNAME set to \"yes\"" do
      it "returns a list of all devices with DHCLIENT_SET_HOSTNAME=\"yes\"" do
        expect(Yast::Lan.find_set_hostname_ifaces).to eql ["eth0"]
      end
    end

    context "when no configuration has DHCLIENT_SET_HOSTNAME set to \"yes\"" do
      let(:connections) do
        Y2Network::ConnectionConfigsCollection.new([conn_no, conn_undef])
      end

      it "returns empty list" do
        expect(Yast::Lan.find_set_hostname_ifaces).to be_empty
      end
    end
  end

  describe "#valid_dhcp_cfg?" do
    let(:hostname) do
      instance_double(Y2Network::Hostname, dhcp_hostname: true)
    end

    context "fails when DHCLIENT_SET_HOSTNAME is set for multiple ifaces" do
      let(:conn_yes_2) do
        instance_double(
          Y2Network::ConnectionConfig::Base,
          interface:             "eth1",
          dhclient_set_hostname: "yes"
        )
      end

      let(:connections) do
        Y2Network::ConnectionConfigsCollection.new([conn_yes, conn_yes_2])
      end

      it "reports configuration as invalid" do
        puts "invalid_dhcp_cfgs: #{Yast::Lan.invalid_dhcp_cfgs}"
        expect(Yast::Lan.invalid_dhcp_cfgs).not_to include("dhcp")
        expect(Yast::Lan.invalid_dhcp_cfgs).to include("ifcfg-eth0")
        expect(Yast::Lan.invalid_dhcp_cfgs).to include("ifcfg-eth1")
        expect(Yast::Lan.valid_dhcp_cfg?).to be false
      end
    end

    it "fails when DHCLIENT_SET_HOSTNAME is set globaly even in an ifcfg" do
      expect(Yast::Lan.invalid_dhcp_cfgs).to include("dhcp")
      expect(Yast::Lan.invalid_dhcp_cfgs).to include("ifcfg-eth0")
      expect(Yast::Lan.valid_dhcp_cfg?).to be false
    end

    context "succeedes when DHCLIENT_SET_HOSTNAME is set for one iface" do
      let(:hostname) do
        instance_double(Y2Network::Hostname, dhcp_hostname: false)
      end

      it "validates the setup" do
        expect(Yast::Lan.invalid_dhcp_cfgs).to be_empty
        expect(Yast::Lan.valid_dhcp_cfg?).to be true
      end
    end

    context "when only global DHCLIENT_SET_HOSTNAME is set" do
      let(:connections) do
        Y2Network::ConnectionConfigsCollection.new([])
      end

      it "validates the setup" do
        expect(Yast::Lan.invalid_dhcp_cfgs).to be_empty
        expect(Yast::Lan.valid_dhcp_cfg?).to be true
      end
    end
  end
end
