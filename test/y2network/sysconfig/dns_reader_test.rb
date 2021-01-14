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
require_relative "../../test_helper"
require "y2network/sysconfig/dns_reader"
require "y2network/sysconfig/hostname_reader"

describe Y2Network::Sysconfig::DNSReader do
  subject(:reader) { described_class.new }

  describe "#config" do
    let(:netconfig_dns) do
      {
        "NETCONFIG_DNS_POLICY"            => "auto",
        "NETCONFIG_DNS_STATIC_SERVERS"    => "1.1.1.1 2.2.2.2",
        "NETCONFIG_DNS_STATIC_SEARCHLIST" => "example.net mydomain"
      }
    end

    let(:netconfig_dhcp) do
      { "DHCLIENT_SET_HOSTNAME" => "yes" }
    end

    let(:netconfig) do
      { "config" => netconfig_dns, "dhcp" => netconfig_dhcp }
    end

    let(:hostname_reader) { instance_double(Y2Network::Sysconfig::HostnameReader) }

    let(:ifcfg_eth0) do
      instance_double(
        CFA::InterfaceFile, interface: "eth0", dhclient_set_hostname: nil,
        load: nil
      )
    end

    before do
      allow(Yast::SCR).to receive(:Read) do |arg|
        key_parts = arg.to_s.split(".")
        netconfig.dig(*key_parts[3..-1])
      end
      allow(Y2Network::Sysconfig::HostnameReader).to receive(:new).and_return(hostname_reader)
      allow(CFA::InterfaceFile).to receive(:all).and_return([ifcfg_eth0])
    end

    it "returns the DNS configuration" do
      config = reader.config
      expect(config).to be_a(Y2Network::DNS)
    end

    it "includes the list of name servers" do
      config = reader.config
      expect(config.nameservers).to eq([IPAddr.new("1.1.1.1"), IPAddr.new("2.2.2.2")])
    end

    context "when no name servers are defined" do
      let(:netconfig_dns) do
        { "NETCONFIG_DNS_STATIC_SERVERS" => "" }
      end

      it "includes an empty list of name servers" do
        config = reader.config
        expect(config.nameservers).to eq([])
      end
    end

    it "includes a list of domains to search" do
      config = reader.config
      expect(config.searchlist).to eq(["example.net", "mydomain"])
    end

    context "when no list of domains to search is defined" do
      let(:netconfig_dns) do
        { "NETCONFIG_DNS_STATIC_SEARCHLIST" => "" }
      end

      it "includes an empty list of domains to search" do
        config = reader.config
        expect(config.searchlist).to eq([])
      end
    end

    it "sets the DNS policy" do
      config = reader.config
      expect(config.resolv_conf_policy).to eq("auto")
    end

    context "when no DNS policy is specified" do
      let(:netconfig_dns) do
        { "NETCONFIG_DNS_POLICY" => "" }
      end

      it "sets the policy to the 'default' value" do
        config = reader.config
        expect(config.resolv_conf_policy).to eq("default")
      end
    end
  end
end
