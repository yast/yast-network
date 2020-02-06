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
require "y2network/presenters/dns_summary"
require "y2network/dns"

describe Y2Network::Presenters::DNSSummary do
  subject(:presenter) { described_class.new(config) }

  let(:dns) do
    Y2Network::DNS.new(
      nameservers: nameservers, searchlist: searchlist
    )
  end

  let(:config) do
    Y2Network::Config.new(
      interfaces: interfaces, connections: connections,
      source: :testing, hostname: hostname, dns: dns
    )
  end

  let(:eth0) do
    config = Y2Network::ConnectionConfig::Ethernet.new.tap(&:propose)
    config.name = "eth0"
    config
  end

  let(:eth1) do
    config = Y2Network::ConnectionConfig::Ethernet.new.tap(&:propose)
    config.name = "eth1"
    config
  end

  let(:interfaces) do
    Y2Network::InterfacesCollection.new(
      [
        double(Y2Network::Interface, hardware: double.as_null_object, name: "eth1"),
        double(Y2Network::Interface, hardware: double.as_null_object, name: "eth0")
      ]
    )
  end

  let(:connections) do
    Y2Network::ConnectionConfigsCollection.new([eth0, eth1])
  end

  let(:hostname) { Y2Network::Hostname.new(static: system_hostname) }
  let(:system_hostname) { "test" }
  let(:nameservers) { [IPAddr.new("1.1.1.1"), IPAddr.new("8.8.8.8")] }
  let(:searchlist) { ["example.net", "example.org"] }

  describe "#text" do
    it "returns a summary in text form" do
      text = presenter.text
      expect(text).to include("Hostname: test")
      expect(text).to include("Name Servers: 1.1.1.1, 8.8.8.8")
      expect(text).to include("Search List: example.net, example.org")
    end

    context "when the hostname is set by DHCP" do
      before do
        eth0.bootproto = Y2Network::BootProtocol::DHCP
        hostname.dhcp_hostname = "eth0"
      end

      it "is shown as the hostname" do
        expect(presenter.text).to include("Hostname: Set by DHCP")
      end
    end

    context "when the config does not contains a system hostname" do
      let(:system_hostname) { "" }

      it "does not show the hostname" do
        expect(presenter.text).to_not include("Hostname")
      end
    end

    context "when the config does not contains name servers" do
      let(:nameservers) { [] }

      it "does not show the name servers" do
        expect(presenter.text).to_not include("Name Servers")
      end
    end

    context "when the config does not contains search domains" do
      let(:searchlist) { [] }

      it "does not show the search domains" do
        expect(presenter.text).to_not include("Search List")
      end
    end
  end
end
