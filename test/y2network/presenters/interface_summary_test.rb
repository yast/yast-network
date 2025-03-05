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
require "y2network/s390_group_devices_collection"
require "y2network/presenters/interface_summary"

describe Y2Network::Presenters::InterfaceSummary do
  subject(:presenter) { described_class.new(name, config) }

  let(:name) { "eth0" }

  let(:config) do
    Y2Network::Config.new(
      interfaces: interfaces, connections: connections, source: :testing
    )
  end
  let(:interfaces) do
    Y2Network::InterfacesCollection.new(
      [
        double(Y2Network::Interface, hardware: nil, name: "vlan1", firmware_configured?: false,
          renaming_mechanism: :none),
        double(Y2Network::Interface, hardware: double.as_null_object, name: "eth1",
          firmware_configured?: false, renaming_mechanism: :mac),
        double(Y2Network::Interface, hardware: double.as_null_object, name: "eth0",
          firmware_configured?: false, renaming_mechanism: :bus_id)
      ]
    )
  end
  let(:connections) do
    Y2Network::ConnectionConfigsCollection.new([vlan1, eth0])
  end

  let(:vlan1) do
    config = Y2Network::ConnectionConfig::Vlan.new.tap(&:propose)
    config.name = "vlan1"
    config.parent_device = "eth0"
    config
  end

  let(:eth0) do
    config = Y2Network::ConnectionConfig::Ethernet.new.tap(&:propose)
    config.name = "eth0"
    config.ip = eth0_ip
    config
  end

  let(:eth0_ip) do
    Y2Network::ConnectionConfig::IPConfig.new(
      Y2Network::IPAddress.from_string("192.168.122.1/24"),
      id: "", broadcast: Y2Network::IPAddress.from_string("192.168.122.255"),
      remote_address: Y2Network::IPAddress.from_string("192.168.122.254")
    )
  end

  describe "#text" do
    it "returns a summary in text form" do
      expect(presenter.text).to be_a(String)
    end

    context "when an empty name is given" do
      let(:name) { "" }

      it "returns an empty text" do
        expect(presenter.text).to eql("")
      end
    end

    context "when an interface is using some renaming mechanism" do
      it "is shown in the summary" do
        text = presenter.text
        expect(text).to include("Renaming mechanism : </b>BusID")
      end
    end

    context "when a remote IP address is configured" do
      it "is shown in the summary" do
        text = presenter.text
        expect(text).to include("remote 192.168.122.254")
      end
    end
  end
end
