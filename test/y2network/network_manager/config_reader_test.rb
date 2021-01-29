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

require_relative "../../test_helper"
require "y2network/network_manager/config_reader"
require "y2network/network_manager/connection_configs_reader"

describe Y2Network::NetworkManager::ConfigReader do
  subject(:reader) { described_class.new }

  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.interface = "eth0"
    end
  end

  let(:connections) do
    Y2Network::ConnectionConfigsCollection.new([eth0_conn])
  end

  let(:connection_configs_reader) do
    instance_double(
      Y2Network::NetworkManager::ConnectionConfigsReader,
      connections: connections
    )
  end

  before do
    allow(Y2Network::NetworkManager::ConnectionConfigsReader).to receive(:new)
      .and_return(connection_configs_reader)
  end

  describe "#config" do
    it "returns a configuration including connection configurations" do
      config = reader.config
      expect(config.connections.to_a).to eq([eth0_conn])
    end

    it "sets 'source' to :network_manager" do
      config = reader.config
      expect(config.source).to eq(:network_manager)
    end

    it "sets 'backend' to network manager" do
      config = reader.config
      expect(config.backend).to be_a(Y2Network::Backends::NetworkManager)
    end
  end
end
