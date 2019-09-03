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

require_relative "../test_helper"
require "y2network/virtual_interface"
require "y2network/connection_config/bridge"

describe Y2Network::VirtualInterface do
  subject(:interface) { described_class.new("br0", type: type) }

  let(:type) { Y2Network::InterfaceType::BRIDGE }

  describe ".from_connection" do
    let(:conn) do
      Y2Network::ConnectionConfig::Bridge.new.tap { |c| c.name = "br0" }
    end

    it "returns a virtual interface using connection's and type" do
      interface = described_class.from_connection(conn)
      expect(interface).to be_a(described_class)
      expect(interface.name).to eq("br0")
      expect(interface.type).to eq(Y2Network::InterfaceType::BRIDGE)
    end
  end
end
