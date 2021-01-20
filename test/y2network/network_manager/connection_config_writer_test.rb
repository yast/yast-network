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

require "y2network/network_manager/connection_config_writer"
require "y2network/network_manager/connection_config_writers/ethernet"
require "y2network/connection_config/ethernet"
require "y2network/interface_type"
require "cfa/nm_connection"

describe Y2Network::NetworkManager::ConnectionConfigWriter do
  subject(:writer) { described_class.new }

  let(:conn) do
    instance_double(
      Y2Network::ConnectionConfig::Ethernet,
      name:      "eth0",
      interface: "eth0",
      type:      Y2Network::InterfaceType::ETHERNET,
      ip:        ip_config
    )
  end

  let(:old_conn) do
    instance_double(
      Y2Network::ConnectionConfig::Ethernet,
      name:      "eth0",
      interface: "eth0",
      type:      Y2Network::InterfaceType::ETHERNET
    )
  end

  let(:ip_config) do
    Y2Network::ConnectionConfig::IPConfig.new(Y2Network::IPAddress.from_string("10.100.0.1/24"))
  end

  let(:path) { "/etc/NetworkManager/system-connections/eth0.nmconnection" }

  let(:file) do
    instance_double(CFA::NmConnection, save: nil, path: path)
  end

  describe "#write" do
    let(:handler) do
      instance_double(
        Y2Network::NetworkManager::ConnectionConfigWriters::Ethernet, write: nil
      )
    end

    before do
      allow(writer).to receive(:require).and_call_original
      allow(Y2Network::NetworkManager::ConnectionConfigWriters::Ethernet).to receive(:new)
        .and_return(handler)
      allow(CFA::NmConnection).to receive(:new).and_return(file)
      allow(writer).to receive(:ensure_permissions)
      allow(::File).to receive(:exist?).with(Pathname.new(path)).and_return(true)
    end

    it "uses the appropiate handler" do
      expect(writer).to receive(:require).and_return(handler)
      expect(handler).to receive(:write).with(conn)
      writer.write(conn)
    end

    context "when the file does not exist" do
      before do
        allow(::File).to receive(:exist?).with(Pathname.new(path)).and_return(false)
      end

      it "ensures the file is created with the the correct permissions" do
        expect(writer).to receive(:ensure_permissions).with(Pathname.new(path))
        writer.write(conn)
      end
    end

    it "does nothing if the connection has not changed"
  end
end
