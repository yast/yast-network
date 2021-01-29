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
require "y2network/network_manager/connection_configs_reader"
require "y2network/connection_configs_collection"
require "cfa/nm_connection"

describe Y2Network::NetworkManager::ConnectionConfigsReader do
  subject(:reader) { described_class.new }

  let(:conn_files) do
    instance_double(CFA::NmConnection)
  end

  let(:eth0_conn) { Y2Network::ConnectionConfig::Ethernet.new }

  let(:connection_config_reader) do
    instance_double(Y2Network::NetworkManager::ConnectionConfigReader, read: eth0_conn)
  end

  describe "#connections" do
    before do
      allow(CFA::NmConnection).to receive(:all)
        .and_return([conn_files])
      allow(Y2Network::NetworkManager::ConnectionConfigReader).to receive(:new)
        .and_return(connection_config_reader)
    end

    it "returns the connection configurations from the NetworkManager system-connections" do
      conns = subject.connections
      expect(conns).to be_a(Y2Network::ConnectionConfigsCollection)
      expect(conns.to_a).to eq([eth0_conn])
    end
  end
end
