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
require "y2network/network_manager/connection_config_writers/vlan"
require "cfa/nm_connection"
require "y2network/connection_config/vlan"

describe Y2Network::NetworkManager::ConnectionConfigWriters::Vlan do
  subject(:handler) { described_class.new(file) }
  let(:file) { CFA::NmConnection.new("vlan1006.nm_connection") }

  let(:conn) do
    Y2Network::ConnectionConfig::Vlan.new.tap do |c|
      c.interface = "eth0.1006"
      c.vlan_id = 1006
      c.parent_device = "eth0"
    end
  end

  describe "#write" do
    it "sets VLAN device attributes" do
      handler.write(conn)
      expect(file.vlan["id"]).to eql("1006")
      expect(file.vlan["parent"]).to eql("eth0")
      expect(file.vlan["type"]).to eql("vlan")
    end
  end
end
