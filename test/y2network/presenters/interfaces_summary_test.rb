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

require "y2network/config"
require "y2network/connection_config"
require "y2network/connection_configs_collection"
require "y2network/interface"
require "y2network/interfaces_collection"
require "y2network/presenters/interfaces_summary"

describe Y2Network::Presenters::InterfacesSummary do
  subject(:presenter) { described_class.new(config) }
  MULTIPLE_INTERFACES = N_("Multiple Interfaces")

  # testing scenario: TODO: have easy yaml mockup format
  # - eth0 configured
  # - eth1 unconfingured
  # - vlan1 on top of eth0
  let(:config) do
    Y2Network::Config.new(
      interfaces: interfaces, connections: connections, source: :testing
    )
  end

  let(:interfaces) do
    Y2Network::InterfacesCollection.new(
      [
        double(Y2Network::Interface, hardware: nil, name: "vlan1"),
        double(Y2Network::Interface, hardware: double.as_null_object, name: "eth1"),
        double(Y2Network::Interface, hardware: double.as_null_object, name: "eth0")
      ]
    )
  end

  let(:connections) do
    Y2Network::ConnectionConfigsCollection.new([vlan1, eth0])
  end

  let(:vlan1) do
    config = Y2Network::ConnectionConfig::Vlan.new.tap(&:propose)
    config.name = config.interface = "vlan1"
    config.parent_device = "eth0"
    config
  end

  let(:eth0) do
    config = Y2Network::ConnectionConfig::Ethernet.new.tap(&:propose)
    config.name = config.interface = "eth0"
    config.bootproto = Y2Network::BootProtocol::DHCP
    config
  end

  describe "#text" do
    it "returns a summary in text form" do
      text = presenter.text
      expect(text).to be_a(::String)
    end

    it "returns an unsorted list with intefaces information as the list items" do
      text = presenter.text
      expect(text).to include("<ul><li>")
      expect(text).to include("eth0")
    end
  end

  describe "#one_line_text" do
    it "returns a plain text summary of the configured interfaces in one line" do
      expect(presenter.one_line_text).to eql(MULTIPLE_INTERFACES)
    end

    context "when there are no configured interfaces" do
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([]) }

      it "returns Yast::Summary.NotConfigured" do
        expect(presenter.one_line_text).to eql(Yast::Summary.NotConfigured)
      end
    end

    context "when there is only one configured interface" do
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0]) }

      it "returns 'protocol / interface name'" do
        expect(subject.one_line_text).to eql "DHCP / eth0"
      end
    end

    context "when there are multiple interfaces" do
      context "sharing the same bootproto" do
        it "returns 'protocol / Multiple Interfaces'" do
          eth0.bootproto = Y2Network::BootProtocol::STATIC
          expect(subject.one_line_text).to eql("STATIC / #{MULTIPLE_INTERFACES}")
        end
      end

      context "with different bootproto" do
        it "returns 'Multiple Interfaces'" do
          expect(subject.one_line_text).to eql(MULTIPLE_INTERFACES)
        end
      end
    end
  end

  describe "#proposal_text" do
    it "returns a summary in rich text form" do
      text = presenter.proposal_text
      expect(text).to be_a(::String)
      expect(text).to include("<ul><li>")
    end

    it "the summary contains information of the configured interfaces" do
      text = presenter.proposal_text
      expect(text).to include("Configured with DHCP: eth0")
      expect(text).to include("Statically configured: vlan1")
    end
  end
end
