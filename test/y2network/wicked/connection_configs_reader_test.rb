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
require "y2network/wicked/connection_configs_reader"
require "y2network/physical_interface"
require "y2network/interfaces_collection"
require "y2network/connection_config"

describe Y2Network::Wicked::ConnectionConfigsReader do
  subject(:reader) { described_class.new }

  let(:eth0) do
    Y2Network::PhysicalInterface.new("eth0")
  end

  let(:ifcfg_eth0) do
    instance_double(
      CFA::InterfaceFile,
      interface: "eth0"
    )
  end

  let(:ifcfg_br0) do
    instance_double(
      CFA::InterfaceFile,
      interface: "br0"
    )
  end

  let(:interfaces) { Y2Network::InterfacesCollection.new([eth0]) }
  let(:ifcfg_files) { [ifcfg_eth0, ifcfg_br0] }

  let(:connection_config_reader) do
    instance_double(Y2Network::Wicked::ConnectionConfigReader)
  end
  let(:conn_eth0) { instance_double(Y2Network::ConnectionConfig) }
  let(:conn_br0) { instance_double(Y2Network::ConnectionConfig) }

  describe "#connections" do
    before do
      allow(CFA::InterfaceFile).to receive(:all).and_return(ifcfg_files)
      allow(Y2Network::Wicked::ConnectionConfigReader)
        .to receive(:new).and_return(connection_config_reader)
    end

    it "returns a connection for each file" do
      expect(connection_config_reader).to receive(:read)
        .with("eth0", Y2Network::InterfaceType::ETHERNET)
        .and_return(conn_eth0)
      expect(connection_config_reader).to receive(:read)
        .with("br0", nil)
        .and_return(conn_br0)

      connections = reader.connections(interfaces)
      expect(connections.to_a).to eq([conn_eth0, conn_br0])
    end
  end
end
