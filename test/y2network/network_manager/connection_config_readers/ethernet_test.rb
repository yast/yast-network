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

require_relative "../../../test_helper"
require_relative "../../../support/network_manager_examples"
require "y2network/network_manager/connection_config_readers/ethernet"
require "y2network/connection_config/ethernet"
require "cfa/nm_connection"

describe Y2Network::NetworkManager::ConnectionConfigReaders::Ethernet do
  subject(:handler) { described_class.new(file) }

  let(:file) do
    instance_double(
      CFA::NmConnection,
      connection: hash_to_augeas_tree({}),
      ethernet:   hash_to_augeas_tree("mtu" => "1024"),
      ipv4:       hash_to_augeas_tree({}),
      ipv6:       hash_to_augeas_tree({})
    )
  end

  let(:connection) { hash_to_augeas_tree("id" => "Cable Connection") }

  include_examples "NetworkManager::ConfigReader"

  describe "#connection_config" do
    it "returns an ethernet connection config object" do
      eth = handler.connection_config
      expect(eth).to be_a(Y2Network::ConnectionConfig::Ethernet)
    end

    it "sets the mtu if present" do
      eth = handler.connection_config
      expect(eth.mtu).to eq(1024)
    end
  end
end
