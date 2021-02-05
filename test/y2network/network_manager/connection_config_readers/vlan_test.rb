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
require "y2network/network_manager/connection_config_readers/vlan"
require "y2network/connection_config/vlan"
require "cfa/nm_connection"

describe Y2Network::NetworkManager::ConnectionConfigReaders::Vlan do
  subject(:handler) { described_class.new(file) }

  let(:file) do
    instance_double(
      CFA::NmConnection,
      connection: hash_to_augeas_tree({}),
      ethernet:   hash_to_augeas_tree("mtu" => "1024"),
      ipv4:       hash_to_augeas_tree({}),
      ipv6:       hash_to_augeas_tree({}),
      vlan:       hash_to_augeas_tree("id" => "0", "parent" => "eth0")
    )
  end

  let(:connection) { hash_to_augeas_tree("id" => "Cable Connection") }

  include_examples "NetworkManager::ConfigReader"

  describe "#connection_config" do
    it "returns an ethernet connection config object" do
      eth = handler.connection_config
      expect(eth).to be_a(Y2Network::ConnectionConfig::Vlan)
    end

    it "sets the vlan ID" do
      eth = handler.connection_config
      expect(eth.vlan_id).to eq(0)
    end

    it "sets the parent device" do
      eth = handler.connection_config
      expect(eth.parent_device).to eq("eth0")
    end
  end
end
