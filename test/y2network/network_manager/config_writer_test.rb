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
require_relative "../../support/config_writer_examples"
require "y2network/network_manager/config_writer"
require "y2network/config"
require "y2network/connection_configs_collection"
require "y2network/interface"
require "y2network/interfaces_collection"

describe Y2Network::NetworkManager::ConfigWriter do
  subject(:writer) { described_class.new }

  include_examples "ConfigWriter"

  describe "#write" do
    let(:old_config) do
      Y2Network::Config.new(
        source:      :network_manager,
        interfaces:  Y2Network::InterfacesCollection.new([eth0]),
        connections: Y2Network::ConnectionConfigsCollection.new([])
      )
    end

    let(:config) do
      old_config.copy.tap do |cfg|
        cfg.add_or_update_connection_config(eth0_conn)
      end
    end

    let(:eth0_conn) do
      Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
        conn.interface = "eth0"
        conn.name = "eth0"
        conn.bootproto = :static
        conn.ip = ip
      end
    end

    let(:ip) { Y2Network::ConnectionConfig::IPConfig.new(address: IPAddr.new("192.168.122.2")) }
    let(:eth0) { Y2Network::Interface.new("eth0") }

    let(:conn_config_writer) do
      instance_double(Y2Network::NetworkManager::ConnectionConfigWriter, write: nil)
    end

    before do
      allow(Y2Network::NetworkManager::ConnectionConfigWriter).to receive(:new)
        .and_return(conn_config_writer)
      allow(writer).to receive(:write_dns)
      allow(writer).to receive(:write_drivers)
      allow(writer).to receive(:write_hostname)
      allow(writer).to receive(:write_routing)
    end

    it "writes connections configuration" do
      expect(conn_config_writer).to receive(:write).with(eth0_conn, nil, routes: [])
      writer.write(config)
    end
  end
end
