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
require "y2network/presenters/interface_summary"

describe Y2Network::Presenters::InterfaceSummary do
  subject(:presenter) { described_class.new(name, config) }

  let(:name) { "vlan1" }

  let(:config) do
    Y2Network::Config.new(
      interfaces: interfaces, connections: connections, source: :testing
    )
  end
  let(:interfaces) do
    Y2Network::InterfacesCollection.new([
                                          double(Y2Network::Interface, hardware: nil, name: "vlan1"),
                                          double(Y2Network::Interface, hardware: double.as_null_object, name: "eth1"),
                                          double(Y2Network::Interface, hardware: double.as_null_object, name: "eth0")
                                        ])
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
    config
  end

  describe "#text" do
    it "returns a summary in text form" do
      text = presenter.text
      expect(text).to be_a(::String)
    end
  end
end
